# Scripts

## Collect and deliver

### Quick start

```
git clone https://github.com/RexxLA/net-oo-rexx.git
rexx net-oo-rexx/scripts/collect    # creates ./cache
rexx net-oo-rexx/scripts/deliver    # creates ./delivery
```


### Usage

```
rexx collect [cache]
rexx deliver [cache [delivery]]
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

- The updates to `cache` and `delivery` are incremental.  
  You can re-run the scripts at any time.

- The resulting `delivery` directory is ready to use as a portable delivery.  
  Follow the instructions in [readme.txt][readme.txt].

- Tested on Windows, WSL Ubuntu and macOS.

- On Windows, the executable bit for Linux and macOS is not set.


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


### Cache and delivery

The default for `cache` is `./cache`.  
The default for `delivery` is `./delivery`.

If `cache` or `delivery` does not exist then a confirmation is requested to 
continue:  
Press `Enter` to continue, or `Ctrl-C` to abort.

A cache is simply a set of components collected using `svn` or `git`, or downloaded.  
The `collect` scripts prevent the creation of a cache inside an existing SVN 
working copy or Git clone.

> [!CAUTION]
> Do not add files to a delivery directory created by `deliver`.  
> The `deliver` scripts use `robocopy` or `rsync` in mirroring mode.  
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

- Delete the previous `cache` and `delivery` directories.
- Run `collect`.
- Run `deliver`.

Deleting the directories is optional but recommended, to avoid delivering obsolete
files that may have been removed.
 

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
