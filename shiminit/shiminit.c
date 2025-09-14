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
    pr('!', format,  ##__VA_ARGS__);  \
    sync();                           \
    /* reboot(LINUX_REBOOT_CMD_RESTART); */ \
    _exit(1);                         \
} while(0)

struct mntpoint {
    const char *dev;
    const char *fs_type;
    const char *where;
    mode_t mode;
    const char *options;
    unsigned long flags;
};

static const char nix_mount_opts_9p[] =
    "trans=virtio,version=9p2000.L,cache=mmap,msize=1048576";

static struct mntpoint mntpoints[] = {
    { NULL,         "proc",     "/proc", 0555, NULL,              0 },
    { NULL,         "sysfs",    "/sys",  0555, NULL,              0 },
    { NULL,         "devtmpfs", "/dev",  0755, NULL,              0 }, // FIXME: this can fail if devtmpfs is not supported (?)
    { NULL,         "tmpfs",    "/run",  0755, NULL,              0 },
    { "nixshare",   "9p",       "/nix",  0755, nix_mount_opts_9p, 0 },
    { NULL,         NULL,       NULL,    0,    NULL,              0 },
};

// static const char init_path[] = "/nix/var/nix/profiles/system/init";

int main() {

    pr_info("shiminit started");

    for (struct mntpoint *mp = mntpoints; mp->where; mp++) {

        pr_info("mounting \"%s\" (\"%s\") at \"%s\" (%04o), options: \"%s\"",
            mp->dev ? mp->dev : "(null)",
            mp->fs_type,
            mp->where,
            mp->mode,
            mp->options ? mp->options : "(none)");

        if (mkdir(mp->where, mp->mode) == -1 && errno != EEXIST)
            pr_die("mkdir(\"%s\", %04o): %m", mp->where, mp->mode);

        if (mount(mp->dev, mp->where, mp->fs_type, mp->flags, mp->options) == -1)
            pr_die("mount(\"%s\", \"%s\", \"%s\", 0x%lx, \"%s\"): %m",
                mp->dev ? mp->dev : "(null)",
                mp->where,
                mp->fs_type,
                mp->flags,
                mp->options ? mp->options : "");
    }

    // pr_info("exec: %s", init_path);
    // char *const new_argv[] = { "init", NULL };
    // execv(init_path, new_argv);
    // pr_die("execv(%s) failed: %m", init_path);

    pr_die("exec() is not implemented yet");
    return 1;
}
