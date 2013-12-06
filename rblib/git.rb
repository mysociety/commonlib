# This file contains wrappers for useful operations on git
# repositories.

module MySociety
  module Git

    # This function returns true if the directory passes a quick check
    # that it has the basic structure of a git repository by checking
    # for the existence of 'objects' and 'refs' subdirectories, and
    # otherwise returns false.  These are necessary for a git
    # repository, but of course this isn't sufficient to tell you that
    # it's actually a working git repository.
    def Git.has_objects_and_refs?(directory)
      ['objects', 'refs'].all? do |subdirectory|
        File.directory? File.join(directory, subdirectory)
      end
    end

    # This function returns true if the directory appears to have the
    # structure of a non-bare git repository; i.e. that it has a .git
    # subdirectory, and that subdirectory contains 'objects' and
    # 'refs'.
    def Git.non_bare_repository?(directory)
      git_directory = File.join directory, '.git'
      return false unless File.directory? git_directory
      has_objects_and_refs? git_directory
    end

    # This function returns true if the output of running 'git status'
    # in repository_directory would indicate that the repository is
    # "clean", and returns false otherwise.  (This could alternatively
    # be implemented by checking if the output of `git status
    # --porcelain` is empty.)
    def Git.status_clean(repository_directory)
      FileUtils.cd repository_directory do
        return false unless system 'git', 'diff', '--exit-code'
        return false unless system 'git', 'diff', '--cached', '--exit-code'
        # We know there are no uncommitted modifications now, so check
        # for untracked files:
        opts = '--others --directory --no-empty-directory --exclude-standard'
        untracked = `git ls-files #{opts}`
        return (untracked.strip.length == 0)
      end
    end

    # Set the URL for a given remote, raising an exception on any
    # error.
    def Git.remote_set_url(repository_directory, remote, url)
      FileUtils.cd repository_directory do
        unless system 'git', 'remote', 'set-url', remote, url
          message = "Failed to set the URL for remote #{remote} to #{url}"
          message += " in #{repository_directory}"
          raise message
        end
      end
    end

    # Runs "git fetch <REMOTE>" for the given remote to update its
    # remote-tracking branches, raising an exception on any error.
    def Git.fetch(repository_directory, remote)
      FileUtils.cd repository_directory do
        unless system 'git', 'fetch', remote
          raise "'git fetch #{remote}' failed in #{repository_directory}"
        end
      end
    end

    # Checks if the commit pointed to by HEAD is contained in any of
    # the remote-tracking branches; this is a reasonable way to check
    # if the commit at HEAD has been pushed at some point.  An
    # exception is raised on any error.
    def Git.is_HEAD_pushed?(repository_directory)
      FileUtils.cd repository_directory do
        # Find all remote-tracking branches that contain HEAD:
        command = 'git branch -r --contains HEAD'
        rtbs = `#{command}`
        unless $? == 0
          raise "'#{command}' failed in #{repository_directory}"
        end
        return rtbs.strip.length > 0
      end
    end

    # Check whether a given committish (e.g. a tag, a branch, an
    # object name, etc.) can be found in the repository.
    def Git.committish_exists?(repository_directory, committish)
      FileUtils.cd repository_directory do
        return system 'git', 'rev-parse', '--verify', '--quiet', committish
      end
    end

    # Check out the commit given by committish; this may detach HEAD
    # if that's not a branch name, as with "git checkout".  An
    # exception is raised on any error.
    def Git.checkout(repository_directory, committish)
      FileUtils.cd repository_directory do
        unless system 'git', 'checkout', committish, '--'
          raise "Checking out #{committish} in #{repository_directory} failed"
        end
      end
    end

  end
end
