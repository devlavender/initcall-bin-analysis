=====================
initcall-bin-analysis
=====================

1. PURPOSE
==========

This is a small script for the analysis of initcall binary/assembly output in
the linux kernel, at first just to collect data. It's intended to be executed
in the kernel tree.

It collects binaries for later reference under a certain config and build
scenario, focusing on the vmlinux image, the main.o, etc.

You can use this to compare different build scenarios (i.e. before and after a
patch) with different testing kernel configs.

2. USAGE
========

To collect the said information, the following steps are necessary:
1. Checkout and enter the kernel tree
2. Configure the kernel
3. Build the kernel
4. Set `STORE` environment variable using export or pass through command-line
5. Add the script directory to the PATH
6. Run:
$ STORE=/path/to/output/tree initcall-collect.sh BUILD-SCENARIO CONFIG-SCENARIO

The BUILD-SCENARIO is a string describing the build, i.e. pre-changes
The CONFIG-SCENARIO is a string describing the config, i.e. gcc-no-lto

This will create a directory
/path/to/output/tree/BUILD-SCENARIO/CONFIG-SCENARIO/ containing the collected
data.

3. COPYRIGHT
============

This tool have been written by Agatha Isabelle Moreira and is license under the
GPL v2 license. See the `LICENSE` file or access it online:
https://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
