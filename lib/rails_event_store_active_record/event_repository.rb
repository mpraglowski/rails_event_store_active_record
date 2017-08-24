require 'activerecord-import'

module RailsEventStoreActiveRecord
  class EventRepository
    def initialize(adapter: Event)
      @adapter = adapter
    end
    attr_reader :adapter

    def append_to_stream(events, stream_name, expected_version=nil)
      events = [*events]
      in_stream = events.flat_map.with_index do |event, index|
        Event.create!(
          id: event.event_id,
          data: event.data,
          metadata: event.metadata,
          event_type: event.class,
        )
        [EventInStream.new(
          stream: stream_name,
          position: index,
          event_id: event.event_id
        ),EventInStream.new(
          stream: "__global__",
          position: nil,
          event_id: event.event_id
        )]
      end
      EventInStream.import(in_stream)
    end

    def create(event, stream_name)
      data = event.to_h.merge!(stream: stream_name, event_type: event.class)
      adapter.create(data)
      event
    end

    def delete_stream(stream_name)
      condition = {stream: stream_name}
      adapter.destroy_all condition
    end

    def has_event?(event_id)
      adapter.exists?(event_id: event_id)
    end

    def last_stream_event(stream_name)
      build_event_entity(adapter.where(stream: stream_name).last)
    end

    def read_events_forward(stream_name, start_event_id, count)
      stream = adapter.where(stream: stream_name)
      unless start_event_id.equal?(:head)
        starting_event = adapter.find_by(event_id: start_event_id)
        stream = stream.where('id > ?', starting_event)
      end

      stream.order('id ASC').limit(count)
        .map(&method(:build_event_entity))
    end

    def read_events_backward(stream_name, start_event_id, count)
      stream = adapter.where(stream: stream_name)
      unless start_event_id.equal?(:head)
        starting_event = adapter.find_by(event_id: start_event_id)
        stream = stream.where('id < ?', starting_event)
      end

      stream.order('id DESC').limit(count)
        .map(&method(:build_event_entity))
    end

    def read_stream_events_forward(stream_name)
      EventInStream.preload(:event).where(stream: stream_name).order('position ASC, id ASC')
        .map(&method(:build_event_entity))
    end

    def read_stream_events_backward(stream_name)
      adapter.where(stream: stream_name).order('id DESC')
        .map(&method(:build_event_entity))
    end

    def read_all_streams_forward(start_event_id, count)
      stream = EventInStream.where(stream: "__global__")
      unless start_event_id.equal?(:head)
        stream = stream.where('event_id > ?', start_event_id)
      end

      stream.preload(:event).order('id ASC').limit(count)
        .map(&method(:build_event_entity))
    end

    def read_all_streams_backward(start_event_id, count)
      stream = adapter
      unless start_event_id.equal?(:head)
        starting_event = adapter.find_by(event_id: start_event_id)
        stream = stream.where('id < ?', starting_event)
      end

      stream.order('id DESC').limit(count)
        .map(&method(:build_event_entity))
    end

    private

    def build_event_entity(record)
      return nil unless record
      record.event.event_type.constantize.new(
        event_id: record.event.id,
        metadata: record.event.metadata,
        data: record.event.data
      )
    end
  end
end
