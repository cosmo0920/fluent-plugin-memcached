require 'test/unit'
require 'fluent/test'
require 'fluent/plugin/out_memcached'

class MemcachedOutputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  CONFIG = %[
    host 127.0.0.1
    port 11211
  ]

  CONFIG_JSON = %[
    host 127.0.0.1
    port 11211
    value_format json
    param_names param1,param2
  ]

  CONFIG_INCREMENT = %[
    host 127.0.0.1
    port 11211
    increment true
  ]

  CONFIG_MYSQL = %[
    host 127.0.0.1
    port 11211
    value_separater |
  ]

  def create_driver(conf = CONFIG, tag='test')
    Fluent::Test::BufferedOutputTestDriver.new(Fluent::MemcachedOutput, tag).configure(conf)
  end

  def test_configure
    d = create_driver('')
    assert_equal 'localhost', d.instance.host
    assert_equal 11211, d.instance.port
    assert_equal false, d.instance.increment
    assert_equal ' ', d.instance.value_separater

    d = create_driver
    assert_equal '127.0.0.1', d.instance.host
    assert_equal 11211, d.instance.port

    d = create_driver(CONFIG_JSON)
    assert_equal '127.0.0.1', d.instance.host
    assert_equal 11211, d.instance.port
    assert_equal 'json', d.instance.value_format
    assert_equal 'param1,param2', d.instance.param_names

    assert_raise(Fluent::ConfigError) {
      create_driver %[
        host 127.0.0.1
        port 11211
        value_format json
      ]
    }

    d = create_driver(CONFIG_INCREMENT)
    assert_equal '127.0.0.1', d.instance.host
    assert_equal 11211, d.instance.port
    assert_equal true, d.instance.increment

    d = create_driver(CONFIG_MYSQL)
    assert_equal '127.0.0.1', d.instance.host
    assert_equal 11211, d.instance.port
    assert_equal '|', d.instance.value_separater
  end

  def test_format
    d = create_driver
    time = Time.parse('2011-01-02 13:14:15 UTC').to_i
    record = {'key' => 'key', 'param1' => 'value'}
    d.emit(record, time)
    d.expect_format(['test', time, record].to_msgpack)
    d.run
  end

  def test_write
    d = create_driver
    time = Time.parse('2011-01-02 13:14:15 UTC').to_i
    record1 = {'key' => 'a', 'param1' => '1'}
    record2 = {'key' => 'b', 'param1' => '2', 'param2' => '3'}
    d.emit(record1, time)
    d.emit(record2, time)
    d.run

    assert_equal '1', d.instance.memcached.get('a')
    assert_equal '2 3', d.instance.memcached.get('b')
  end

  def test_write_json
    d = create_driver(CONFIG_JSON)
    time = Time.parse('2011-01-02 13:14:15 UTC').to_i
    record1 = {'key' => 'c', 'param1' => '4'}
    record2 = {'key' => 'd', 'param1' => '5', 'param2' => '6'}
    record1_value_json = {'param1' => '4', 'param2' => nil}.to_json
    record2_value_json = {'param1' => '5', 'param2' => '6'}.to_json
    d.emit(record1, time)
    d.emit(record2, time)
    d.run

    assert_equal record1_value_json, d.instance.memcached.get('c')
    assert_equal record2_value_json, d.instance.memcached.get('d')
  end

  def test_write_increment
    d = create_driver(CONFIG_INCREMENT)
    time = Time.parse('2011-01-02 13:14:15 UTC').to_i
    record1 = {'key' => 'count1', 'param1' => 1}
    record2 = {'key' => 'count2', 'param1' => 2}
    record3 = {'key' => 'count1', 'param1' => 3}
    record4 = {'key' => 'count2', 'param1' => 4}
    d.emit(record1, time)
    d.emit(record2, time)
    d.emit(record3, time)
    d.emit(record4, time)
    d.run

    assert_equal (1 + 3), d.instance.memcached.get('count1').to_i
    assert_equal (2 + 4), d.instance.memcached.get('count2').to_i
  end

  def test_write_to_mysql
    d = create_driver(CONFIG_MYSQL)
    time = Time.parse('2011-01-02 13:14:15 UTC').to_i
    record = {'key' => time, 'metrics_name' => 'count', 'metrics_value' => '100'}
    d.emit(record, time)
    d.run

    assert_equal 'count|100', d.instance.memcached.get(time)
  end

end
