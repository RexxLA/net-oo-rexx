# How to create a release

Illustration for the release 20260117.

Create the zip files.

- net-oo-rexx.macos.universal_64-portable-release-20260117.zip
- net-oo-rexx.ubuntu2404.x86_64-portable-release-20260117.zip
- net-oo-rexx.windows.x86_64-portable-release-20260117.zip

**Don't push the zip files in the Gihub repository.**

Click on Create a new release.

In the Tag field, create a new tag 20260117.  
Click on Create new tag.

Release title:  
net-oo-rexx-20260117

Releases notes:  
Enter what you want.

Select the files to include in the release

If needed, check Set as a pre-release (This release will be labeled as non-production ready)

For testing, you can save as draft.  
This draft release won’t be seen by the public unless it is published

You can retrieve the draft release in the list of releases  
(click **Releases** on the right, it's a link despite nothing shows it's a link).

When ready to publish,

- select the draft release in the list of releases
- click the pen button to edit the release.
- click Publish release.

Note:  
Github automatically adds auto-generated source code archives (source code.zip and source code.tar.gz).  
It's not possible to remove them.

More details:  
[https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository)
