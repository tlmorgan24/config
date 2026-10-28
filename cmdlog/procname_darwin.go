package main

import (
	"os"

	"golang.org/x/sys/unix"
)

// foregroundName is the name of the process in the foreground of the shell's pty (the shell itself, or the command it's
// running), found the same way VS Code names its terminals. "" if it can't be found.
func foregroundName(ptmx *os.File) string {
	// Use SyscallConn rather than Fd, as Fd would switch the pty to blocking mode.
	conn, err := ptmx.SyscallConn()
	if err != nil {
		return ""
	}
	pgrp, ioctlErr := 0, error(nil)
	if err := conn.Control(func(fd uintptr) { pgrp, ioctlErr = unix.IoctlGetInt(int(fd), unix.TIOCGPGRP) }); err != nil || ioctlErr != nil {
		return ""
	}
	kp, err := unix.SysctlKinfoProc("kern.proc.pid", pgrp) // The process group leader, i.e. the command started
	if err != nil {
		return ""
	}
	return unix.ByteSliceToString(kp.Proc.P_comm[:])
}
