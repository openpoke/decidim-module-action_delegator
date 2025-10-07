# frozen_string_literal: true

namespace :action_delegator do
  desc "Migrate old decidim-consultations data to decidim-elections component"
  task :migrate_consultations, [:component_id, :consultation_id] => :environment do |_task, args|
    component_id = args[:component_id]
    consultation_id = args[:consultation_id]

    if component_id.blank?
      puts "ERROR: component_id is required"
      puts "Usage: rake action_delegator:migrate_consultations[COMPONENT_ID] or rake action_delegator:migrate_consultations[COMPONENT_ID,CONSULTATION_ID]"
      exit 1
    end

    component = Decidim::Component.find_by(id: component_id)
    unless component&.manifest_name == "elections"
      puts "ERROR: Component ##{component_id} not found or is not an elections component"
      exit 1
    end

    # Define inline models for old consultation tables (module no longer exists in Decidim)
    module Legacy
      class Consultation < ApplicationRecord
        self.table_name = "decidim_consultations"
        has_many :questions, class_name: "Legacy::Question", foreign_key: :decidim_consultation_id, dependent: :destroy
      end

      class Question < ApplicationRecord
        self.table_name = "decidim_consultations_questions"
        belongs_to :consultation, class_name: "Legacy::Consultation", foreign_key: :decidim_consultation_id
        has_many :responses, class_name: "Legacy::Response", foreign_key: :decidim_consultations_question_id, dependent: :destroy
        has_many :votes, class_name: "Legacy::Vote", foreign_key: :decidim_consultation_question_id, dependent: :destroy
      end

      class Response < ApplicationRecord
        self.table_name = "decidim_consultations_responses"
        belongs_to :question, class_name: "Legacy::Question", foreign_key: :decidim_consultations_question_id
      end

      class Vote < ApplicationRecord
        self.table_name = "decidim_consultations_votes"
        belongs_to :question, class_name: "Legacy::Question", foreign_key: :decidim_consultation_question_id
        belongs_to :response, class_name: "Legacy::Response", foreign_key: :decidim_consultations_response_id
        belongs_to :author, class_name: "Decidim::User", foreign_key: :decidim_author_id
      end
    end

    # Check if consultations table exists
    unless ActiveRecord::Base.connection.table_exists?("decidim_consultations")
      puts "ERROR: decidim_consultations table not found. Make sure you have legacy data to migrate."
      exit 1
    end

    # Fetch consultations to migrate
    consultations = if consultation_id.present?
                      Legacy::Consultation.where(id: consultation_id, decidim_organization_id: component.organization.id)
                    else
                      Legacy::Consultation.where(decidim_organization_id: component.organization.id)
                    end

    if consultations.empty?
      puts "No consultations found"
      exit 0
    end

    # Calculate source data statistics
    source_stats = {
      consultations: consultations.count,
      questions: 0,
      responses: 0,
      votes: 0
    }

    consultations.each do |c|
      source_stats[:questions] += c.questions.count
      c.questions.each do |q|
        source_stats[:responses] += q.responses.count
        source_stats[:votes] += q.votes.count
      end
    end

    migrated_stats = {
      elections: 0,
      questions: 0,
      responses: 0,
      votes: 0,
      skipped_votes: 0,
      skipped_consultations: 0,
      errors: []
    }

    def determine_census_config(consultation, setting)
      resource_handlers = extract_authorization_handlers(consultation)
      census_manifest = determine_census_manifest(setting, resource_handlers)
      authorization_handlers = determine_authorization_handlers(setting, resource_handlers, census_manifest)
      census_settings = build_census_settings(census_manifest, setting, authorization_handlers)

      [census_manifest, census_settings]
    end

    def extract_authorization_handlers(consultation)
      question_ids = consultation.questions.pluck(:id)
      return [] unless ActiveRecord::Base.connection.table_exists?("decidim_resource_permissions") && question_ids.any?

      handlers = []
      perms = ActiveRecord::Base.connection.execute(<<-SQL.squish)
        SELECT permissions FROM decidim_resource_permissions
        WHERE resource_type = 'Decidim::Consultations::Question'
        AND resource_id IN (#{question_ids.join(",")})
        AND permissions::jsonb -> 'vote' -> 'authorization_handlers' IS NOT NULL
      SQL

      perms.each do |perm|
        perm_handlers = begin
          JSON.parse(perm["permissions"])["vote"]["authorization_handlers"].keys
        rescue StandardError
          []
        end
        handlers.concat(perm_handlers)
      end
      handlers.uniq
    end

    def determine_census_manifest(setting, resource_handlers)
      return "action_delegator_census" if setting&.delegations&.any?
      return "internal_users" if setting&.authorization_method.present? || resource_handlers.any?

      "internal_users"
    end

    def determine_authorization_handlers(setting, resource_handlers, census_manifest)
      return [] if census_manifest == "action_delegator_census"
      return ["delegations_verifier"] if setting&.authorization_method.present?

      resource_handlers
    end

    def build_census_settings(census_manifest, setting, authorization_handlers)
      return { "setting_id" => setting.id } if census_manifest == "action_delegator_census" && setting

      return {} if authorization_handlers.empty?

      {
        authorization_handlers: authorization_handlers.index_with do |handler|
          handler == "delegations_verifier" && setting ? { "options" => { "setting" => setting.id.to_s } } : { "options" => {} }
        end
      }
    end

    def build_question_description(old_question)
      parts = [old_question.subtitle, old_question.what_is_decided].compact.compact_blank
      return {} if parts.empty?

      parts_by_locale = parts.each_with_object({}) do |part, result|
        part.each do |locale, text|
          result[locale] ||= []
          result[locale] << text if text.present?
        end
      end
      parts_by_locale.transform_values { |arr| arr.join("\n\n") }
    end

    def migrate_question_votes(old_question, new_question, response_mapping, migrated_stats)
      votes_migrated = 0
      votes_skipped = 0

      old_question.votes.find_each do |old_vote|
        user = old_vote.author
        unless user
          votes_skipped += 1
          migrated_stats[:skipped_votes] += 1
          next
        end

        new_response_id = response_mapping[old_vote.decidim_consultations_response_id]
        unless new_response_id
          votes_skipped += 1
          migrated_stats[:skipped_votes] += 1
          next
        end

        new_vote = Decidim::Elections::Vote.new(
          question: new_question,
          response_option_id: new_response_id,
          voter_uid: user.to_global_id.to_s,
          created_at: old_vote.created_at,
          updated_at: old_vote.updated_at
        )

        if new_vote.save
          votes_migrated += 1
          migrated_stats[:votes] += 1
        else
          votes_skipped += 1
          migrated_stats[:skipped_votes] += 1
        end
      end

      [votes_migrated, votes_skipped]
    end

    consultations.find_each do |consultation|
      ActiveRecord::Base.transaction do
        setting = Decidim::ActionDelegator::Setting.find_by(decidim_consultation_id: consultation.id)

        # Check if already migrated (idempotency check by matching title)
        existing_election = Decidim::Elections::Election.joins(:component)
                                                        .where(component: component, title: consultation.title)
                                                        .first

        if existing_election
          cons_title = consultation.title["en"] || consultation.title.values.first
          puts "  ✓ Consultation ##{consultation.id} (#{cons_title}) already migrated to Election ##{existing_election.id}"
          migrated_stats[:skipped_consultations] += 1
          next
        end

        census_manifest, census_settings = determine_census_config(consultation, setting)

        # Create Election from Consultation
        election = Decidim::Elections::Election.new(
          component: component,
          title: consultation.title,
          description: consultation.description,
          start_at: consultation.start_voting_date&.to_time&.beginning_of_day,
          end_at: consultation.end_voting_date&.to_time&.end_of_day,
          published_at: consultation.published_at,
          results_availability: "after_end",
          census_manifest: census_manifest,
          census_settings: census_settings,
          created_at: consultation.created_at,
          updated_at: consultation.updated_at
        )

        if election.save
          migrated_stats[:elections] += 1

          consultation.questions.order(:order).each_with_index do |old_question, index|
            new_question = Decidim::Elections::Question.new(
              election: election,
              body: old_question.title,
              description: build_question_description(old_question),
              position: old_question.order || index,
              question_type: "single_option",
              created_at: old_question.created_at,
              updated_at: old_question.updated_at
            )

            unless new_question.save
              migrated_stats[:errors] << "Question creation failed: #{new_question.errors.full_messages.join(", ")}"
              next
            end

            migrated_stats[:questions] += 1

            response_mapping = {}
            old_question.responses.each do |old_response|
              new_response = Decidim::Elections::ResponseOption.new(
                question: new_question,
                body: old_response.title,
                created_at: old_response.created_at,
                updated_at: old_response.updated_at
              )

              if new_response.save
                response_mapping[old_response.id] = new_response.id
                migrated_stats[:responses] += 1
              else
                migrated_stats[:errors] << "Response failed: #{new_response.errors.full_messages.join(", ")}"
              end
            end

            migrate_question_votes(old_question, new_question, response_mapping, migrated_stats)

            new_question.response_options.each { |ro| Decidim::Elections::ResponseOption.reset_counters(ro.id, :votes) }
            Decidim::Elections::Question.reset_counters(new_question.id, :votes)
          end

          # Update election votes count
          election.update_votes_count!
        else
          cons_title = consultation.title["en"] || consultation.title.values.first
          migrated_stats[:errors] << "Consultation ##{consultation.id} (#{cons_title}): #{election.errors.full_messages.join(", ")}"
          raise ActiveRecord::Rollback
        end
      rescue StandardError => e
        cons_title = begin
          consultation.title["en"] || consultation.title.values.first
        rescue StandardError
          "ID #{consultation.id}"
        end
        migrated_stats[:errors] << "Consultation ##{consultation.id} (#{cons_title}): #{e.message}"
        raise ActiveRecord::Rollback
      end
    end

    puts "\n#{"-" * 70}"
    puts "Migration results: Consultations → Elections"
    puts "-" * 70
    puts "                Elections    Questions    Responses        Votes"
    puts "-" * 70
    puts format("%-12s %12d %12d %12d %12d", "SOURCE", source_stats[:consultations], source_stats[:questions], source_stats[:responses], source_stats[:votes])
    puts format("%-12s %12d %12d %12d %12d", "MIGRATED", migrated_stats[:elections], migrated_stats[:questions], migrated_stats[:responses], migrated_stats[:votes])

    puts format("%-12s %12d %12s %12s %12s", "ALREADY", migrated_stats[:skipped_consultations], "-", "-", "-") if migrated_stats[:skipped_consultations].positive?

    puts format("%-12s %12s %12s %12s %12d", "SKIPPED", "-", "-", "-", migrated_stats[:skipped_votes]) if migrated_stats[:skipped_votes].positive?

    if migrated_stats[:errors].any?
      puts "\nErrors (#{migrated_stats[:errors].size}):"
      migrated_stats[:errors].each { |err| puts "  • #{err}" }
    end

    puts ""
    total_processed = migrated_stats[:elections] + migrated_stats[:skipped_consultations]
    success = total_processed == source_stats[:consultations] &&
              migrated_stats[:questions] == source_stats[:questions] &&
              migrated_stats[:responses] == source_stats[:responses] &&
              migrated_stats[:votes] == source_stats[:votes] &&
              migrated_stats[:errors].empty? &&
              (migrated_stats[:skipped_votes]).zero?

    if success
      if migrated_stats[:skipped_consultations].positive?
        puts "✓ All data processed (#{migrated_stats[:elections]} migrated, #{migrated_stats[:skipped_consultations]} already existed)"
      else
        puts "✓ All data migrated successfully"
      end
    else
      puts "⚠ Some data was not migrated (see details above)"
    end
  end
end
