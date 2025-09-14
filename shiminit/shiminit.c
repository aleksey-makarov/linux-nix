#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <linux/reboot.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mount.h>
#include <sys/reboot.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#define pr( ch, format, ... ) \
    fprintf(stderr, "%c %s():%d : " format "\n", ch, __func__, __LINE__, ##__VA_ARGS__)

#define pr_info( format, ... ) \
    pr('-', format,  ##__VA_ARGS__)

#define pr_err( format, ... ) \
    pr('*', format,  ##__VA_ARGS__)

#define pr_die( format, ... ) do {    \
    pr('!', format,  ##__VA_ARGS__);   \
    sync();                           \
    /* reboot(LINUX_REBOOT_CMD_RESTART); */ \
    /* _exit(1);                         */ \
} while(0)

static void must_mkdir(const char *p, mode_t m) {
    if (mkdir(p, m) == -1 && errno != EEXIST) {
        pr_die("mkdir(%s): %m", p);
    }
}

static void must_mount(const char *src, const char *tgt, const char *type,
                       unsigned long flags, const char *data) {
    if (mount(src, tgt, type, flags, data) == -1)
        pr_die("mount(%s -> %s, type=%s, data=\"%s\"): %m",
            src ? src : "(null)", tgt, type ? type : "(null)",
            data ? data : "");
}

static const char *fs_type = "9p";
static const char *nix_tag = "nixshare";
static const char *init_path = "/nix/var/nix/profiles/system/init";
static const char *nix_mount_opts_9p =
    "trans=virtio,version=9p2000.L,cache=mmap,msize=1048576";

static void parse_args(int argc, char **argv) {
    for (int i = 1; i < argc; ++i) {
        if (!strncmp(argv[i], "--fs=", 5)) {
            fs_type = argv[i] + 5;               // "9p" | "virtiofs"
        } else if (!strncmp(argv[i], "--tag=", 6)) {
            nix_tag = argv[i] + 6;               // name of mount_tag
        } else if (!strncmp(argv[i], "--init=", 7)) {
            init_path = argv[i] + 7;             // path to stage-2 init
        } else {
            pr_info("warning: unknown arg ignored: %s", argv[i]);
        }
    }
}

int main(int argc, char **argv) {

    pr_info("shiminit started");

    must_mkdir("/proc", 0555);
    must_mkdir("/sys",  0555);
    must_mkdir("/dev",  0755);
    must_mkdir("/run",  0755);
    must_mkdir("/nix",  0755);

    parse_args(argc, argv);

    pr_info("booting: fs=%s tag=%s init=%s", fs_type, nix_tag, init_path);

    if (mount("devtmpfs", "/dev", "devtmpfs", 0, "") == -1)
        pr_info("note: devtmpfs mount failed: %s", strerror(errno));
    must_mount("proc", "/proc", "proc", 0, "");
    must_mount("sysfs", "/sys", "sysfs", 0, "");

    if (!strcmp(fs_type, "9p")) {
        must_mount(nix_tag, "/nix", "9p", 0, nix_mount_opts_9p);
    } else if (!strcmp(fs_type, "virtiofs")) {
        must_mount(nix_tag, "/nix", "virtiofs", 0, "");
    } else {
        pr_die("unsupported fs type for /nix: %s", fs_type);
    }

    pr_info("exec: %s", init_path);
    char *const new_argv[] = { "init", NULL };
    execv(init_path, new_argv);

    pr_die("execv(%s) failed: %m", init_path);
    return 1;
}
