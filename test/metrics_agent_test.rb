require File.dirname(__FILE__) + '/test_helper.rb'


module AMQPLogging
  class MetricsAgentTest < Test::Unit::TestCase
    def setup
      @agent = MetricsAgent.new
      @out = StringIO.new
      @agent.logger = Logger.new(@out)
    end
    
    test "should record the process id" do
      assert_equal Process.pid, @agent[:pid]
    end
    
    test "should record the hostname" do
      assert_equal Socket.gethostname.split('.').first, @agent[:host]
    end
    
    test "should have convenience methods for accessing the fields" do
      @agent[:foo] = :bar
      assert_equal :bar, @agent[:foo]
      assert_equal @agent[:foo], @agent[:foo]
    end
    
    test "should send the collected data as json when flushed" do
      @agent.flush
      json = JSON.parse(@out.string)
      assert_equal Process.pid, json["pid"]
    end
    
    test "should reset the collected data when flushed" do
      
    end
  end

  class LoggingProxyTest < Test::Unit::TestCase
    def setup
      @agent = MetricsAgent.new
      @logger = ::Logger.new('/dev/null')
      @proxy = @agent.wrap_logger(@logger)
    end

    test "should return a logger proxy that quaks like a regular logger" do
      @logger.expects(:debug)
      @proxy.debug "foobar"
    end

    test "should register every logline on the agent" do
      @agent.expects(:add_logline).with(0, nil, "foobar", @logger)
      @proxy.debug("foobar")
    end

    test "should take the loglevel of the logger into account" do
      @logger.level = ::Logger::INFO
      no_lines_before_logging = @agent[:loglines][:default].size
      @logger.debug "something"
      assert_equal no_lines_before_logging, @agent[:loglines][:default].size
    end

    test "should store the loglines" do
      assert_equal 0, @agent[:loglines][:default].size
      @proxy.debug("foobar")
      assert_equal 1, @agent[:loglines][:default].size
    end

    test "should store each logline with severity, a timestamp and the message" do
      some_logline = "asdf0asdf"
      @proxy.debug "foo"
      @proxy.warn  "bar"
      @proxy.info  some_logline
      severity, timestamp, message = @agent[:loglines][:default][2]
      assert_equal Logger::INFO, severity
      assert_nothing_raised { Time.parse(timestamp) }
      assert_equal some_logline, message
    end
    
    test "should allow to register multiple loggers with different types" do
      other_logger = ::Logger.new('/dev/null')
      @agent.wrap_logger(other_logger, :sql)
      other_logger.info("some fancy stuff here")
      assert_equal 1, @agent[:loglines][:sql].size
    end
  end
end
