# frozen_string_literal: true

module Decidim
  module ActionDelegator
    module Admin
      class CreateSetting < Decidim::Command
        # Public: Initializes the command.
        #
        # form         - A form object with the params.
        def initialize(form, copy_from_setting)
          @form = form
          @copy_from_setting = copy_from_setting
        end

        # Executes the command. Broadcasts these events:
        #
        # - :ok when everything is valid.
        # - :invalid if the form wasn't valid and we couldn't proceed.
        #
        # Returns nothing.
        def call
          return broadcast(:invalid) if form.invalid?

          create_setting

          broadcast(:ok, setting)
        end

        private

        attr_reader :form, :setting

        def create_setting
          # selected = @copy_from_setting || Setting.new(ponderations: [], participants: [])
          selected = Setting.new(ponderations: [], participants: [])

          created_setting = Setting.new(
            max_grants: form.max_grants,
            authorization_method: form.authorization_method,
            ponderations: selected.ponderations.map(&:dup),
            participants: selected.participants.map(&:dup)
          )

          @setting = created_setting.save!
        end
      end
    end
  end
end
