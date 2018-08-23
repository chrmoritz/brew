require "json"

module Language
  module Node
    def self.npm_cache_config
      "cache=#{HOMEBREW_CACHE}/npm_cache"
    end

    # Read https://gist.github.com/chrmoritz/34e4c4d7779d72b549e2fc41f77c365c
    # for a complete overview of the edge cases this method has to handle.
    def self.pack_for_installation(prepare_required: false)
      # Rewrites the package.json so that npm pack will bundle all deps
      # into a self-contained package, so that we avoid installing them a
      # second time during the final installation of the package to libexec.
      pkg_json = JSON.parse(IO.read("package.json"))
      if pkg_json["dependencies"]
        pkg_json["bundledDependencies"] = pkg_json["dependencies"].keys
        IO.write("package.json", JSON.pretty_generate(pkg_json))
      end

      # Backup generation of lockfile if none exists
      # (both npm calls are still faster than installing without a lockfile)
      unless Pathname("package-lock.json").exist? || Pathname("npm-shrinkwrap.json").exist?
        npm_args = ["-ddd", "--package-lock-only"]
        npm_args << "--production" unless prepare_required
        safe_system "npm", "install", *npm_args
      end

      # If `prepare_required` is false we pass `--production` to install all
      # production deps (no devDeps) for bundling them into the pack and also
      # to prevent the toplevel prepare / prepublish script from being executed
      # while still executing all lifecycle scripts for the deps.
      # Otherwise we omit `--production` to install all deps (devDeps might be
      # required in `prepare`). This already executes the prepare script too,
      # so that we can continue to `npm pack` with `--ignore-scripts`.
      npm_args = local_npm_install_args
      npm_args << "--production" unless prepare_required
      safe_system "npm", "ci", *npm_args

      # Homebrew assumes the buildpath/testpath will always be disposable
      # and from npm 5.0.0 the logic changed so that when a directory is
      # fed to `npm install` only symlinks are created linking back to that
      # directory, consequently breaking that assumption. We require a tarball
      # because npm install creates a "real" installation when fed a tarball.
      output = Utils.popen_read("npm pack --ignore-scripts")
      if !$CHILD_STATUS.exitstatus.zero? || output.lines.empty?
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

    def self.std_npm_install_args(libexec, prepare_required: false)
      setup_npm_environment
      # tell npm to not install .brew_home by adding it to the .npmignore file
      # (or creating a new one if no .npmignore file already exists)
      open(".npmignore", "a") { |f| f.write("\n.brew_home\n") }

      pack = pack_for_installation(prepare_required: prepare_required)

      # npm install args for global style module format installed into libexec
      %W[
        -ddd
        --global
        --build-from-source
        --no-audit
        --production
        --#{npm_cache_config}
        --prefix=#{libexec}
        #{Dir.pwd}/#{pack}
      ]
    end

    def self.local_npm_install_args(prepare_required: true)
      setup_npm_environment

      # npm install args for local style module format
      npm_args = %W[
        -ddd
        --build-from-source
        --no-audit
        --#{npm_cache_config}
      ]
      npm_args << "--production" unless prepare_required

      npm_args
    end
  end
end
