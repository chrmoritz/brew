module Language
  module Node
    def self.npm_cache_config
      "cache=#{HOMEBREW_CACHE}/npm_cache\n"
    end

    def self.pack_for_installation(prepublish_requires_deps, pack_skip_prepublish)
      # Some packages are requiring (dev)dependencies to be in place when
      # running the prepublish script (which is run before pack). In this case
      # we have to install all dependencies a first time already before
      # executing npm pack (and a second time when doing the actual install).
      safe_system "npm", "install" if prepublish_requires_deps

      # Homebrew assumes the buildpath/testpath will always be disposable
      # and from npm 5.0.0 the logic changed so that when a directory is
      # fed to `npm install` only symlinks are created linking back to that
      # directory, consequently breaking that assumption. We require a tarball
      # because npm install creates a "real" installation when fed a tarball.
      output = Utils.popen_read("npm pack" + (pack_skip_prepublish ? " --ignore-scripts" : ""))
      unless $CHILD_STATUS.exitstatus.zero? && !output.lines.empty?
        raise "npm failed to pack #{Dir.pwd}"
      end
      output.lines.last.chomp
    end

    def self.setup_npm_environment
      # guard that this is only run once
      return if @env_set
      @env_set = true
      # explicitly use our npm and node-gyp executables instead of the user
      # managed ones in HOMEBREW_PREFIX/lib/node_modules which might be broken
      begin
        ENV.prepend_path "PATH", Formula["node"].opt_libexec/"bin"
      rescue FormulaUnavailableError
        nil
      end
    end

    def self.std_npm_install_args(libexec, prepublish_requires_deps = false, pack_skip_prepublish = false)
      setup_npm_environment
      # tell npm to not install .brew_home by adding it to the .npmignore file
      # (or creating a new one if no .npmignore file already exists)
      open(".npmignore", "a") { |f| f.write("\n.brew_home\n") }

      pack = pack_for_installation(prepublish_requires_deps, pack_skip_prepublish)

      # npm install args for global style module format installed into libexec
      %W[
        --ddd
        --global
        --prefix=#{libexec}
        --#{npm_cache_config}
        --build-from-source
        #{Dir.pwd}/#{pack}
      ]
    end

    def self.local_npm_install_args
      setup_npm_environment
      # npm install args for local style module format
      %W[
        --ddd
        --#{npm_cache_config}
        --build-from-source
      ]
    end
  end
end
