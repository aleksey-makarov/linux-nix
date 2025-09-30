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

#define pr_die( format, ... ) do {   \
    pr('!', format,  ##__VA_ARGS__); \
    sync();                          \
    reboot(LINUX_REBOOT_CMD_HALT);   \
    _exit(1);                        \
} while(0)

struct mntpoint {
    const char *fs_type;
    const char *where;
    mode_t mode;
};

static const char nix_mount_opts_9p[] =
    "trans=virtio,version=9p2000.L,cache=mmap,msize=1048576";

static struct mntpoint mntpoints[] = {
    { "proc",     "/proc", 0555, },
    { "sysfs",    "/sys",  0555, },
    { "devtmpfs", "/dev",  0755, },
    { "tmpfs",    "/run",  0755, },
    { NULL,       NULL,    0,    },
};

int main() {

    pr_info("shiminit started");

    for (struct mntpoint *mp = mntpoints; mp->where; mp++) {

        pr_info("mounting NULL (\"%s\") at \"%s\" (%04o), options: NULL",
            mp->fs_type,
            mp->where,
            mp->mode);

        if (mkdir(mp->where, mp->mode) == -1 && errno != EEXIST)
            pr_die("mkdir(\"%s\", %04o): %m", mp->where, mp->mode);

        if (mount(NULL, mp->where, mp->fs_type, 0, NULL) == -1) {

            // devtmpfs may already be mounted automatically by the kernel
            if (strcmp(mp->fs_type, "devtmpfs") == 0 && errno == EBUSY) {
                pr_info("devtmpfs already mounted at %s, skipping", mp->where);
                continue;
            }

            pr_die("mount(NULL, \"%s\", \"%s\", 0, NULL): %m",
                mp->where,
                mp->fs_type);
        }
    }

    pr_info("mounting \"nixshare\" (\"9p\") at \"/nix/store\" (0755), options: \"%s\"",
        nix_mount_opts_9p);

    if (mkdir("/nix", 0755) == -1 && errno != EEXIST)
        pr_die("mkdir(\"%s\", %04o): %m", "/nix", 0755);

    if (mkdir("/nix/store", 0755) == -1 && errno != EEXIST)
        pr_die("mkdir(\"%s\", %04o): %m", "/nix/store", 0755);

    if (mount("nixshare", "/nix/store", "9p", 0, nix_mount_opts_9p) == -1)
        pr_die("mount(\"nixshare\", \"/nix/store\", \"9p\", 0x0, \"%s\"): %m",
            nix_mount_opts_9p);

    // Parse kernel command line to find systemConfig=xxx
    pr_info("parsing kernel command line for systemConfig parameter");

    FILE *cmdline = fopen("/proc/cmdline", "r");
    if (!cmdline) {
        pr_die("failed to open /proc/cmdline: %m");
    }

    char cmdline_buf[4096];
    if (!fgets(cmdline_buf, sizeof(cmdline_buf), cmdline)) {
        pr_die("failed to read /proc/cmdline: %m");
    }
    fclose(cmdline);

    // Remove newline character at the end
    size_t len = strlen(cmdline_buf);
    if (len > 0 && cmdline_buf[len-1] == '\n') {
        cmdline_buf[len-1] = '\0';
    }

    pr_info("kernel command line: %s", cmdline_buf);

    // Look for systemConfig= parameter
    char *system_config = NULL;
    char *token = strtok(cmdline_buf, " \t");
    while (token != NULL) {
        if (strncmp(token, "systemConfig=", 13) == 0) {
            system_config = token + 13; // skip "systemConfig="
            break;
        }
        token = strtok(NULL, " \t");
    }

    if (system_config) {
        pr_info("found systemConfig parameter: %s", system_config);
    } else {
        pr_die("systemConfig parameter not found in kernel command line");
    }

    char exec_buf[4096];
    snprintf(exec_buf, sizeof(exec_buf), "%s/init", system_config);
    exec_buf[sizeof(exec_buf)-1] = '\0'; // ensure null-termination
    pr_info("exec: %s", exec_buf);
    char *const new_argv[] = { "init", NULL };
    execv(exec_buf, new_argv);
    pr_die("execv(\"%s\") failed: %m", exec_buf);

    return 1;
}
