require "language/node"

describe Language::Node do
  #describe "#setup_npm_environment" do
  #  it "calls prepend_path when node formula exists and only once" do
  #    node = formula "node" do
  #      url "node-test"
  #    end
  #    stub_formula_loader(node)
  #    subject.setup_npm_environment
  #    expect(ENV).to receive(:prepend_path)
  #    expect(subject.env_set).to be == true
  #    subject.setup_npm_environment
  #  end
  #end

  describe "#std_npm_install_args" do
    npm_install_arg = "libexec"

    it "raises error with non zero exitstatus" do
      expect { subject.std_npm_install_args(npm_install_arg) }.to \
        raise_error("npm failed to pack #{Dir.pwd}")
    end

    it "does not raise error with a zero exitstatus" do
      allow(Utils).to receive(:popen_read).with("npm pack").and_return("pack")
      allow_any_instance_of(Process::Status).to receive(:exitstatus).and_return(0)
      allow_any_instance_of(nil::NilClass).to receive(:exitstatus).and_return(0)
      resp = subject.std_npm_install_args(npm_install_arg)
      expect(resp).to include("--prefix=#{npm_install_arg}", "#{Dir.pwd}/pack")
    end
  end

  specify "#local_npm_install_args" do
    resp = subject.local_npm_install_args
    expect(resp).to include("--ddd", "--build-from-source", "--cache=#{HOMEBREW_CACHE}/npm_cache")
  end
end
