# frozen_string_literal: true

require 'test_helper'

class PersistenceTest < Minitest::Test
  def setup
    super
    @test_class = Class.new do
      include Whodunit::Chronicles::Persistence

      attr_accessor :connection, :audit_database_url

      def initialize
        @connection = nil
        @audit_database_url = nil
      end

      # Make private methods public for testing
      public :persist_record, :persist_record_postgresql, :persist_record_mysql,
        :persist_records_batch, :persist_records_batch_postgresql,
        :persist_records_batch_mysql, :build_record_params

      # Add detect_database_type method for testing
      def detect_database_type(url)
        return :postgresql if url&.include?('postgres')
        return :mysql if url&.include?('mysql')

        :postgresql # default
      end
    end

    @instance = @test_class.new
    @sample_record = {
      table_name: 'users',
      schema_name: 'public',
      record_id: { 'id' => 1 },
      action: 'INSERT',
      old_data: nil,
      new_data: { 'id' => 1, 'name' => 'John' },
      changes: { 'name' => [nil, 'John'] },
      user_id: 10,
      user_type: 'User',
      transaction_id: 'txn_123',
      sequence_number: 1,
      occurred_at: Time.now,
      created_at: Time.now,
      metadata: { 'source' => 'test' },
    }
  end

  def test_persist_record_postgresql
    @instance.audit_database_url = 'postgres://user:pass@localhost/db'
    mock_connection = mock('connection')
    @instance.connection = mock_connection

    expected_sql = <<~SQL
      INSERT INTO whodunit_chronicles_audits (
        table_name, schema_name, record_id, action, old_data, new_data, changes,
        user_id, user_type, transaction_id, sequence_number, occurred_at, created_at, metadata
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
      RETURNING id
    SQL

    expected_params = [
      'users', 'public', '{"id":1}', 'INSERT', nil, '{"id":1,"name":"John"}',
      '{"name":[null,"John"]}', 10, 'User', 'txn_123', 1,
      @sample_record[:occurred_at], @sample_record[:created_at], '{"source":"test"}'
    ]

    mock_result = mock('result')
    mock_result.expects(:first).returns({ 'id' => '123' })
    mock_result.expects(:clear)

    mock_connection.expects(:exec_params).with(expected_sql, expected_params).returns(mock_result)

    result = @instance.persist_record_postgresql(@sample_record)

    assert_equal 123, result[:id]
    assert_equal @sample_record, result
  end

  def test_persist_record_mysql
    @instance.audit_database_url = 'mysql://user:pass@localhost/db'
    mock_connection = mock('connection')
    @instance.connection = mock_connection

    expected_sql = <<~SQL
      INSERT INTO whodunit_chronicles_audits (
        table_name, schema_name, record_id, action, old_data, new_data, changes,
        user_id, user_type, transaction_id, sequence_number, occurred_at, created_at, metadata
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    SQL

    expected_params = [
      'users', 'public', '{"id":1}', 'INSERT', nil, '{"id":1,"name":"John"}',
      '{"name":[null,"John"]}', 10, 'User', 'txn_123', 1,
      @sample_record[:occurred_at], @sample_record[:created_at], '{"source":"test"}'
    ]

    mock_connection.expects(:execute).with(expected_sql, *expected_params)
    mock_connection.expects(:last_insert_id).returns(456)

    result = @instance.persist_record_mysql(@sample_record)

    assert_equal 456, result[:id]
    assert_equal @sample_record, result
  end

  def test_persist_record_dispatches_to_postgresql
    @instance.audit_database_url = 'postgres://user:pass@localhost/db'

    @instance.expects(:persist_record_postgresql).with(@sample_record).returns(@sample_record)

    result = @instance.persist_record(@sample_record)

    assert_equal @sample_record, result
  end

  def test_persist_record_dispatches_to_mysql
    @instance.audit_database_url = 'mysql://user:pass@localhost/db'

    @instance.expects(:persist_record_mysql).with(@sample_record).returns(@sample_record)

    result = @instance.persist_record(@sample_record)

    assert_equal @sample_record, result
  end

  def test_persist_record_uses_config_database_url
    Whodunit::Chronicles.config.database_url = 'postgres://config:pass@localhost/db'

    @instance.expects(:persist_record_postgresql).with(@sample_record).returns(@sample_record)

    result = @instance.persist_record(@sample_record)

    assert_equal @sample_record, result
  end

  def test_persist_records_batch_empty_records
    result = @instance.persist_records_batch([])

    assert_empty result
  end

  def test_persist_records_batch_dispatches_to_postgresql
    @instance.audit_database_url = 'postgres://user:pass@localhost/db'
    records = [@sample_record]

    @instance.expects(:persist_records_batch_postgresql).with(records).returns(records)

    result = @instance.persist_records_batch(records)

    assert_equal records, result
  end

  def test_persist_records_batch_dispatches_to_mysql
    @instance.audit_database_url = 'mysql://user:pass@localhost/db'
    records = [@sample_record]

    @instance.expects(:persist_records_batch_mysql).with(records).returns(records)

    result = @instance.persist_records_batch(records)

    assert_equal records, result
  end

  def test_persist_records_batch_postgresql_single_record
    mock_connection = mock('connection')
    @instance.connection = mock_connection

    records = [@sample_record]

    expected_sql = <<~SQL
      INSERT INTO whodunit_chronicles_audits (
        table_name, schema_name, record_id, action, old_data, new_data, changes,
        user_id, user_type, transaction_id, sequence_number, occurred_at, created_at, metadata
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
      RETURNING id
    SQL

    expected_params = [
      'users', 'public', '{"id":1}', 'INSERT', nil, '{"id":1,"name":"John"}',
      '{"name":[null,"John"]}', 10, 'User', 'txn_123', 1,
      @sample_record[:occurred_at], @sample_record[:created_at], '{"source":"test"}'
    ]

    mock_result = mock('result')
    mock_result.expects(:each_with_index).yields({ 'id' => '789' }, 0)
    mock_result.expects(:clear)

    mock_connection.expects(:exec_params).with(expected_sql, expected_params).returns(mock_result)

    result = @instance.persist_records_batch_postgresql(records)

    assert_equal 789, result[0][:id]
    assert_equal records, result
  end

  def test_persist_records_batch_postgresql_multiple_records
    mock_connection = mock('connection')
    @instance.connection = mock_connection

    # Create completely separate record objects
    record1 = @sample_record.dup
    record2 = {
      table_name: 'posts',
      schema_name: 'public',
      record_id: { 'id' => 2 },
      action: 'UPDATE',
      old_data: { 'id' => 2, 'name' => 'Jane' },
      new_data: { 'id' => 2, 'name' => 'John' },
      changes: { 'name' => %w[Jane John] },
      user_id: 10,
      user_type: 'User',
      transaction_id: 'txn_123',
      sequence_number: 2,
      occurred_at: Time.now,
      created_at: Time.now,
      metadata: { 'source' => 'test' },
    }

    records = [record1, record2]

    expected_sql = <<~SQL
      INSERT INTO whodunit_chronicles_audits (
        table_name, schema_name, record_id, action, old_data, new_data, changes,
        user_id, user_type, transaction_id, sequence_number, occurred_at, created_at, metadata
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14), ($15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26, $27, $28)
      RETURNING id
    SQL

    # Build expected params for both records
    expected_params = [
      # First record (record1)
      'users', 'public', '{"id":1}', 'INSERT', nil, '{"id":1,"name":"John"}', '{"name":[null,"John"]}',
      10, 'User', 'txn_123', 1, record1[:occurred_at], record1[:created_at], '{"source":"test"}',
      # Second record (record2)
      'posts', 'public', '{"id":2}', 'UPDATE', '{"id":2,"name":"Jane"}', '{"id":2,"name":"John"}',
      '{"name":["Jane","John"]}',
      10, 'User', 'txn_123', 2, record2[:occurred_at], record2[:created_at], '{"source":"test"}'
    ]

    mock_result = mock('result')
    mock_result.expects(:each_with_index).multiple_yields(
      [{ 'id' => '100' }, 0],
      [{ 'id' => '101' }, 1],
    )
    mock_result.expects(:clear)

    mock_connection.expects(:exec_params).with(expected_sql, expected_params).returns(mock_result)

    result = @instance.persist_records_batch_postgresql(records)

    assert_equal 100, result[0][:id]
    assert_equal 101, result[1][:id]
    assert_equal records, result
  end

  def test_persist_records_batch_mysql_calls_individual_persist
    records = [@sample_record, @sample_record.dup]

    @instance.expects(:persist_record_mysql).with(@sample_record).once
    @instance.expects(:persist_record_mysql).with(@sample_record).once

    result = @instance.persist_records_batch_mysql(records)

    assert_equal records, result
  end

  def test_build_record_params_with_all_fields
    expected_params = [
      'users',                          # table_name
      'public',                         # schema_name
      '{"id":1}', # record_id as JSON
      'INSERT', # action
      nil,                             # old_data (nil converted to JSON)
      '{"id":1,"name":"John"}',        # new_data as JSON
      '{"name":[null,"John"]}',        # changes as JSON
      10,                              # user_id
      'User',                          # user_type
      'txn_123',                       # transaction_id
      1,                               # sequence_number
      @sample_record[:occurred_at],    # occurred_at
      @sample_record[:created_at],     # created_at
      '{"source":"test"}', # metadata as JSON
    ]

    result = @instance.build_record_params(@sample_record)

    assert_equal expected_params, result
  end

  def test_build_record_params_with_old_data
    record_with_old_data = @sample_record.dup
    record_with_old_data[:old_data] = { 'id' => 1, 'name' => 'Jane' }
    record_with_old_data[:action] = 'UPDATE'

    result = @instance.build_record_params(record_with_old_data)

    # Check that old_data is properly serialized
    assert_equal '{"id":1,"name":"Jane"}', result[4]
  end

  # rubocop:disable Minitest/MultipleAssertions
  def test_build_record_params_with_nil_values
    record_with_nils = {
      table_name: 'users',
      schema_name: 'public',
      record_id: { 'id' => 1 },
      action: 'DELETE',
      old_data: { 'id' => 1, 'name' => 'John' },
      new_data: nil,
      changes: {},
      user_id: nil,
      user_type: nil,
      transaction_id: nil,
      sequence_number: nil,
      occurred_at: Time.now,
      created_at: Time.now,
      metadata: {},
    }

    result = @instance.build_record_params(record_with_nils)

    assert_equal 'users', result[0]
    assert_equal 'public', result[1]
    assert_equal '{"id":1}', result[2]
    assert_equal 'DELETE', result[3]
    assert_equal '{"id":1,"name":"John"}', result[4]
    assert_nil result[5] # new_data should be nil
    assert_equal '{}', result[6] # empty changes as JSON
    assert_nil result[7]  # user_id
    assert_nil result[8]  # user_type
    assert_nil result[9]  # transaction_id
    assert_nil result[10] # sequence_number
    assert_equal record_with_nils[:occurred_at], result[11]
    assert_equal record_with_nils[:created_at], result[12]
    assert_equal '{}', result[13] # empty metadata as JSON
  end
  # rubocop:enable Minitest/MultipleAssertions
end
