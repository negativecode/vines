# encoding: UTF-8

module Vines

  # Fork the current process into the background and manage pid
  # files so we can kill the process later.
  class Daemon

    # Configure a new daemon process.  Arguments hash can include the following
    # keys: :pid (pid file name, required),
    # :stdin, :stdout, :stderr (default to /dev/null)
    def initialize(args)
      @pid = args[:pid]
      raise ArgumentError.new('pid file is required') unless @pid
      raise ArgumentError.new('pid must be a file name') if File.directory?(@pid)
      raise ArgumentError.new('pid file must be writable') unless File.writable?(File.dirname(@pid))
      @stdin, @stdout, @stderr = [:stdin, :stdout, :stderr].map {|k| args[k] || '/dev/null' }
    end

    # Fork the current process into the background to start the
    # daemon. Do nothing if the daemon is already running.
    def start
      daemonize unless running?
    end

    # Use the pid stored in the pid file created from a previous
    # call to start to send a TERM signal to the process. Do nothing
    # if the daemon is not running.
    def stop
      10.times do
        break unless running?
        Process.kill('TERM', pid)
        sleep(0.1)
      end
    end

    # Returns true if the process is running as determined by the numeric
    # pid stored in the pid file created by a previous call to start.
    def running?
      begin
        pid && Process.kill(0, pid)
      rescue Errno::ESRCH
        delete_pid
        false
      rescue Errno::EPERM
        true
      end
    end

    # Returns the numeric process ID from the pid file.
    # If the pid file does not exist, returns nil.
    def pid
      File.read(@pid).to_i if File.exists?(@pid) 
    end

    private

    def delete_pid
      File.delete(@pid) if File.exists?(@pid)
    end

    # Fork process into background twice to release it from
    # the controlling tty. Point open file descriptors shared
    # with the parent process to separate destinations (e.g. /dev/null).
    def daemonize
      exit if fork
      Process.setsid
      exit if fork
      Dir.chdir('/')
      $stdin.reopen(@stdin)
      $stdout.reopen(@stdout, 'a').sync = true
      $stderr.reopen(@stderr, 'a').sync = true
      File.open(@pid, 'w') {|f| f.write(Process.pid) }
      at_exit { delete_pid }
      trap('TERM') { exit }
    end
  end
end
