if ENV['CODECLIMATE_REPO_TOKEN']
  require 'simplecov'
  SimpleCov.start
end

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'rails_event_store_active_record'

RSpec.configure do |config|
  config.around(:each) do |example|
    ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
    ActiveRecord::Schema.define do
      self.verbose = false

      create_table(:event_store_events_in_streams) do |t|
        t.string      :stream,      null: false
        t.integer     :position,    null: true
        t.references  :event,       null: false, type: :uuid
        t.datetime    :created_at,  null: false
      end
      add_index :event_store_events_in_streams, [:stream, :position], unique: true
      add_index :event_store_events_in_streams, [:created_at]
      # add_index :event_store_events_in_streams, [:stream, :event_uuid], unique: true
      # add_index :event_store_events_in_streams, [:event_uuid]

      create_table(:event_store_events, id: :uuid) do |t|
        t.string      :event_type,  null: false
        t.text        :metadata
        t.text        :data,        null: false
        t.datetime    :created_at,  null: false
      end
      add_index :event_store_events, :created_at
    end
    example.run
  end
end
