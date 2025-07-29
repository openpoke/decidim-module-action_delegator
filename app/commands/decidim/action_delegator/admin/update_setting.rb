# frozen_string_literal: true

module Decidim
  module ActionDelegator
    module Admin
      class UpdateSetting < Decidim::Command
        # Public: Initializes the command.
        #
        # form         - A form object with the params.
        def initialize(form, setting, copy_from_setting)
          @form = form
          @setting = setting
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

          update_setting

          broadcast(:ok, setting)
        end

        private

        attr_reader :form, :setting, :copy_from_setting

        def update_setting
          setting.assign_attributes(
            title: form.title,
            description: form.description,
            max_grants: form.max_grants,
            authorization_method: form.authorization_method,
            active: form.active
          )

          if copy_from_setting.present?
            new_participants = copy_from_setting.participants.reject do |participant|
              existing_participants.any? { |p| p.email == participant.email || p.phone == participant.phone }
            end
            setting.participants += new_participants.map(&:dup)
          
            new_ponderations = copy_from_setting.ponderations.reject do |ponderation|
              existing_ponderations.any? { |p| p.name == ponderation.name }
            end
            setting.ponderations += new_ponderations.map(&:dup)
          end

          setting.save!
        end

        def existing_participants
          @existing_participants ||= setting.participants.to_a
        end

        def existing_ponderations
          @existing_ponderations ||= setting.ponderations.to_a
        end
      end
    end
  end
end
