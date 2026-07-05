# frozen_string_literal: true

require 'cdc_core'

module Whodunit
  module Chronicles
    # Immutable audit-domain representation of one CDC::Core::ChangeEvent.
    class LedgerEntry < Data.define(
      :event_id,
      :occurred_at,
      :recorded_at,
      :namespace,
      :entity,
      :identity,
      :operation,
      :actor,
      :changes,
      :metadata,
      :payload
    )
      # Build a ledger entry from a normalized CDC change event.
      #
      # @param event [CDC::Core::ChangeEvent] normalized CDC event
      # @param clock [#now] clock used for recorded_at and fallback timestamps
      # @return [LedgerEntry] immutable ledger entry
      # @raise [TypeError] if event is not a CDC::Core::ChangeEvent
      def self.from_change_event(event, clock: Time)
        validate_change_event!(event)

        new(
          event_id: event_id_for(event),
          occurred_at: event.occurred_at || clock.now,
          recorded_at: clock.now,
          namespace: namespace_for(event),
          entity: entity_for(event),
          identity: event.primary_key,
          operation: event.operation,
          actor: actor_for(event),
          changes: changes_for(event),
          metadata: metadata_for(event),
          payload: event.to_h
        )
      end

      class << self
        alias_method :from_event, :from_change_event
      end

      # Convert this entry to a Hash keyed by attribute name.
      #
      # @return [Hash<Symbol, Object>] entry attributes
      def to_h
        members.to_h { |name| [name, public_send(name)] }
      end

      # Build a stable ordering identity for per-record ordering.
      #
      # @return [String] namespace/entity/identity tuple rendered as a string
      def ordering_identity
        [namespace, entity, identity].compact.join(':')
      end

      # Verify the event type.
      #
      # @param event [Object] candidate event
      # @return [true]
      def self.validate_change_event!(event)
        return true if event.is_a?(CDC::Core::ChangeEvent)

        raise TypeError, "expected CDC::Core::ChangeEvent, got #{event.class}"
      end
      private_class_method :validate_change_event!

      # Derive a stable event id from CDC source coordinates.
      #
      # @param event [CDC::Core::ChangeEvent] normalized CDC event
      # @return [String] deterministic event id
      def self.event_id_for(event)
        require 'digest'
        Digest::SHA256.hexdigest(Marshal.dump(event.to_h))
      end
      private_class_method :event_id_for

      # Source-neutral namespace for the changed entity.
      #
      # @param event [CDC::Core::ChangeEvent] normalized CDC event
      # @return [String] namespace value
      def self.namespace_for(event)
        event.schema
      end
      private_class_method :namespace_for

      # Source-neutral entity name for the changed record collection.
      #
      # @param event [CDC::Core::ChangeEvent] normalized CDC event
      # @return [String] entity value
      def self.entity_for(event)
        event.table
      end
      private_class_method :entity_for

      # Extract actor details from event metadata.
      #
      # @param event [CDC::Core::ChangeEvent] normalized CDC event
      # @return [Object, nil] actor metadata
      def self.actor_for(event)
        event.metadata[:actor] || event.metadata[:whodunit]
      end
      private_class_method :actor_for

      # Extract column changes in a persistence-friendly shape.
      #
      # @param event [CDC::Core::ChangeEvent] normalized CDC event
      # @return [Array<Hash>] changed column records
      def self.changes_for(event)
        event.changes.map(&:to_h)
      end
      private_class_method :changes_for

      # Extract ledger metadata from CDC event metadata and source coordinates.
      #
      # @param event [CDC::Core::ChangeEvent] normalized CDC event
      # @return [Hash] metadata hash
      def self.metadata_for(event)
        event.metadata.to_h.merge(
          'transaction_id' => event.transaction_id,
          'source_position' => source_position_for(event),
          'sequence_number' => event.sequence_number
        ).compact
      end
      private_class_method :metadata_for

      # Source-neutral position for checkpoint/replay correlation.
      #
      # @param event [CDC::Core::ChangeEvent] normalized CDC event
      # @return [String, nil] source position
      def self.source_position_for(event)
        event.commit_lsn
      end
      private_class_method :source_position_for
    end
  end
end
