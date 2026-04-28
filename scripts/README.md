# Scripts

## Collect, deliver and release

### Quick start

#### Platform-specific bundles

```
git clone https://github.com/RexxLA/net-oo-rexx.git
rexx net-oo-rexx/scripts/collect    # creates ./cache
rexx net-oo-rexx/scripts/release    # creates ./release
```

#### Platform-agnostic bundle

```
git clone https://github.com/RexxLA/net-oo-rexx.git
rexx net-oo-rexx/scripts/collect    # creates ./cache
rexx net-oo-rexx/scripts/deliver    # creates ./delivery
```

### Usage

```
rexx collect [cache]
rexx deliver [cache [delivery]]
rexx release [cache [release]]
```

It's also possible to execute the per-component scripts directly.

```
rexx collect_oorexx [cache]
rexx deliver_oorexx_incubator_regex [cache [delivery]]
rexx deliver_oorexx_test_trunk [cache [delivery]]

rexx collect_rexx-parser [cache]
rexx deliver_rexx-parser [cache [delivery]]
...
```

**Notes**

- The updates to `cache`, `delivery` and `release` are incremental.  
  You can re-run the scripts at any time.

- The resulting `delivery` directory is ready to use as a platform-agnostic
  bundle that does not include ooRexx. Follow the instructions in [readme.txt][readme.txt].

- The resulting `release` directory contains platform-specific bundles
  that include ooRexx, ready for release on GitHub.

- Tested on Windows, WSL Ubuntu and macOS.

- On Windows, the executable bit for Linux and macOS is not set. The symbolic
  links are lost. DON'T create releases for macOS or Ubuntu on Windows!!!!

- SourceForge is unfriendly to automated downloads:
    - Non-browser agents get redirected to the project page
    - Multi-step HTTP redirects (301 → 302 → actual file)
    - A mirror cookie is set during the redirect

    If an error occurs, delete the offending ZIP file (its content is likely
    HTML), then restart the script until no errors remain.
  

### Naming conventions

The `collect` scripts are named after the repository name.  

- `collect_bsf4oorexx850`
- `collect_executor`
- `collect_netrexx`
- `collect_oorexx`
- `collect_oorexxdebugger`
- `collect_rexx-parser`
- `collect_tutor`

The `delivery` scripts are also named after the repository name, with an optional
component path for modularity.  
Example with ooRexx:

- `deliver_oorexx_incubator_regex`
- `deliver_oorexx_test_trunk`

The `release` scripts are named after their target platform.

- `release_macos`
- `release_ubuntu`
- `release_windows`


### Cache, delivery and release

The default for `cache` is `./cache`.  
The default for `delivery` is `./delivery`.  
The default for `release` is `./release`.

If `cache`, `delivery` or `release` does not exist then a confirmation is
requested to continue:  
_Ok to create the cache|delivery|release directory? (Y/n)_

A cache is simply a set of components collected using `svn` or `git`, or downloaded.  
The `collect` scripts prevent the creation of a cache inside an existing SVN 
working copy or Git clone.

> [!CAUTION]
> Do not add files to a directory created by `deliver` or `release`.  
> The `deliver` and `release` scripts use `robocopy` or `rsync` in mirroring mode.  
> Any files in the destination that are not present in the source will be removed.
>
> Exception: mirroring mode is not used for the delivery's root directory, as this
> would remove the `package` directory. If you run `setup.sh` or `setup.cmd`,
> the generated files `run` and `setenv` will not be removed
> by the next execution of `deliver`.
>
> If you execute the per-component scripts, remember that
> `deliver_net-oo-rexx_source.rex` should be executed last, because other
> scripts will remove any extra directories or extra files.


### When preparing a new release

#### Checklist

Check if the URLs are up to date:

- `collect_bsf4oorexx850.rex`:  
  check the BSF4ooRexx URL.
- `collect_netrexx.rex`:  
  check the NetRexx URL.
- `collect_oorexx.rex`:  
  check the portable URL, check the platforms.

#### Cleanup

Deleting the directories is optional but recommended, to avoid delivering obsolete
files that may have been removed.
 
- Delete the previous `cache`, `delivery` and `release` directories.

#### Bundles

- Run `collect`.
- Run `deliver` if you want to release a platform-agnostic bundle that does not
  include ooRexx binaries.
- Run `release` if you want to release platform-specific bundles that include
  ooRexx binaries.


### When refining the next release

From the same cache, you can deliver to several locations.

```
rexx collect path/to/cache
rexx deliver path/to/cache path/to/windows/release
rexx deliver path/to/cache path/to/linux/release
rexx deliver path/to/cache path/to/macos/release
```

You can incrementally collect and deliver packages.

```
loop
    rexx collect_rexx-parser path/to/cache
    rexx deliver_rexx-parser path/to/cache path/to/windows/release
    test
    if failure then fix and commit to the rexx-parser GitHub repository
until everything is working correctly
```


### Verbose mode

In case of error, you can activate the verbose mode:

- Posix shell: `verbose=1 rexx CollectOrDeliverScript`
- Cmd: `set verbose=1 && rexx CollectOrDeliverScript`
- Powershell: `$env:verbose = 1; rexx CollectOrDeliverScript`


### Trash

When a file or directory needs to be deleted, it is moved to the trash folder.  
This is not the system Recycle Bin, but a regular cache folder.  
Files and directories in the trash folder are suffixed with a counter.  
You can safely delete this trash folder; it will be recreated if necessary.


[readme.txt]: https://github.com/RexxLA/net-oo-rexx/blob/main/source/readme.txt
