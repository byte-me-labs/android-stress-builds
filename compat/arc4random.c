/*
 * arc4random(3) compatibility shim for older Android kernels.
 *
 * The static bionic libc in NDK r30 initialises its RNG with
 * madvise(MADV_WIPEONFORK) and aborts when the kernel lacks support:
 *
 *     arc4random data MADV_WIPEONFORK failed: Invalid argument
 *
 * MADV_WIPEONFORK only exists on Linux 4.14 and newer, so any binary that
 * uses arc4random - directly, or through libc internals such as the setjmp
 * cookie - dies on older devices.  Defining the public entry points here
 * keeps bionic's arc4random object out of the static link entirely.
 *
 * Randomness comes from getrandom(2), which is available on every kernel we
 * support, with /dev/urandom as a fallback.  The implementation keeps no RNG
 * state between calls, so it is fork-safe without bionic's MADV trick.
 *
 * bionic registers arc4random_mutex_lock/unlock with pthread_atfork from
 * libc_init_common; they are no-ops here because there is no shared state to
 * protect.
 */
#include <errno.h>
#include <fcntl.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

/* Declared here rather than in <sys/random.h>: that header marks the call as
 * introduced in API 28, which would warn when building for API 24/26. */
extern ssize_t getrandom(void *buf, size_t len, unsigned int flags);

static size_t fill_from_getrandom(unsigned char *buf, size_t len) {
  size_t done = 0;

  while (done < len) {
    ssize_t n = getrandom(buf + done, len - done, 0);
    if (n > 0) {
      done += (size_t)n;
      continue;
    }
    if (n < 0 && errno == EINTR) {
      continue;
    }
    break;
  }
  return done;
}

static size_t fill_from_urandom(unsigned char *buf, size_t len) {
  size_t done = 0;
  int fd = open("/dev/urandom", O_RDONLY | O_CLOEXEC);

  if (fd < 0) {
    return 0;
  }
  while (done < len) {
    ssize_t n = read(fd, buf + done, len - done);
    if (n > 0) {
      done += (size_t)n;
      continue;
    }
    if (n < 0 && errno == EINTR) {
      continue;
    }
    break;
  }
  close(fd);
  return done;
}

/* Last resort only: reached if both getrandom(2) and /dev/urandom fail. */
static void fill_from_fallback(unsigned char *buf, size_t len) {
  static uint64_t state;
  size_t done = 0;

  if (state == 0) {
    state = ((uint64_t)getpid() << 32) ^ (uint64_t)(uintptr_t)buf ^
            (uint64_t)time(NULL) ^ 0x9e3779b97f4a7c15ULL;
    if (state == 0) {
      state = 0x9e3779b97f4a7c15ULL;
    }
  }
  while (done < len) {
    size_t chunk;
    state ^= state << 13;
    state ^= state >> 7;
    state ^= state << 17;
    chunk = len - done < sizeof(state) ? len - done : sizeof(state);
    memcpy(buf + done, &state, chunk);
    done += chunk;
  }
}

static void random_bytes(void *buf, size_t len) {
  unsigned char *p = buf;
  size_t done = fill_from_getrandom(p, len);

  if (done < len) {
    done += fill_from_urandom(p + done, len - done);
  }
  if (done < len) {
    fill_from_fallback(p + done, len - done);
  }
}

uint32_t arc4random(void) {
  uint32_t value;

  random_bytes(&value, sizeof(value));
  return value;
}

void arc4random_buf(void *buf, size_t len) {
  random_bytes(buf, len);
}

uint32_t arc4random_uniform(uint32_t upper_bound) {
  uint32_t minimum;
  uint32_t value;

  if (upper_bound < 2) {
    return 0;
  }

  /* Reject the low (2^32 % upper_bound) values so the modulo is unbiased. */
  minimum = (uint32_t)(-(uint32_t)upper_bound) % upper_bound;
  do {
    value = arc4random();
  } while (value < minimum);
  return value % upper_bound;
}

/* Referenced by bionic's libc_init_common atfork handler. */
void arc4random_mutex_lock(void) {}
void arc4random_mutex_unlock(void) {}
