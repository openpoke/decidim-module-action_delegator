# frozen_string_literal: true

require "spec_helper"

describe "rake action_delegator:migrate_consultations", type: :task do
  let(:organization) { create(:organization) }
  let!(:component) { create(:elections_component, organization: organization) }

  before do
    # Create legacy consultation tables
    ActiveRecord::Base.connection.execute <<-SQL.squish
      CREATE TABLE IF NOT EXISTS decidim_consultations (
        id bigserial PRIMARY KEY,
        decidim_organization_id bigint NOT NULL,
        title jsonb DEFAULT '{}' NOT NULL,
        subtitle jsonb DEFAULT '{}' NOT NULL,
        description jsonb DEFAULT '{}' NOT NULL,
        slug character varying NOT NULL,
        start_voting_date date NOT NULL,
        end_voting_date date NOT NULL,
        published_at timestamp without time zone,
        created_at timestamp without time zone NOT NULL,
        updated_at timestamp without time zone NOT NULL
      );

      CREATE TABLE IF NOT EXISTS decidim_consultations_questions (
        id bigserial PRIMARY KEY,
        decidim_consultation_id bigint NOT NULL,
        decidim_organization_id bigint NOT NULL,
        title jsonb DEFAULT '{}' NOT NULL,
        subtitle jsonb DEFAULT '{}',
        what_is_decided jsonb DEFAULT '{}',
        slug character varying NOT NULL,
        "order" integer,
        published_at timestamp without time zone,
        votes_count integer DEFAULT 0 NOT NULL,
        created_at timestamp without time zone NOT NULL,
        updated_at timestamp without time zone NOT NULL
      );

      CREATE TABLE IF NOT EXISTS decidim_consultations_responses (
        id bigserial PRIMARY KEY,
        decidim_consultations_questions_id bigint NOT NULL,
        title jsonb DEFAULT '{}' NOT NULL,
        votes_count integer DEFAULT 0 NOT NULL,
        created_at timestamp without time zone NOT NULL,
        updated_at timestamp without time zone NOT NULL
      );

      CREATE TABLE IF NOT EXISTS decidim_consultations_votes (
        id bigserial PRIMARY KEY,
        decidim_consultation_question_id bigint NOT NULL,
        decidim_author_id bigint NOT NULL,
        decidim_consultations_response_id bigint NOT NULL,
        created_at timestamp without time zone NOT NULL,
        updated_at timestamp without time zone NOT NULL
      );
    SQL
  end

  after do
    # Clean up tables
    ActiveRecord::Base.connection.execute <<-SQL.squish
      DROP TABLE IF EXISTS decidim_consultations_votes CASCADE;
      DROP TABLE IF EXISTS decidim_consultations_responses CASCADE;
      DROP TABLE IF EXISTS decidim_consultations_questions CASCADE;
      DROP TABLE IF EXISTS decidim_consultations CASCADE;
    SQL
  end

  context "when migrating a simple consultation without verification" do
    let!(:user) { create(:user, organization: organization) }
    let!(:consultation_id) do
      ActiveRecord::Base.connection.execute(<<-SQL.squish).first["id"]
        INSERT INTO decidim_consultations (
          decidim_organization_id,
          title,
          subtitle,
          description,
          slug,
          start_voting_date,
          end_voting_date,
          published_at,
          created_at,
          updated_at
        ) VALUES (
          #{organization.id},
          '{"en": "Simple Consultation"}'::jsonb,
          '{"en": "No verification required"}'::jsonb,
          '{"en": "All users can vote"}'::jsonb,
          'simple-consultation-#{Time.current.to_i}',
          '#{Date.current - 30.days}',
          '#{Date.current + 30.days}',
          '#{Time.current}',
          '#{Time.current}',
          '#{Time.current}'
        )
        RETURNING id;
      SQL
    end

    let!(:question_id) do
      ActiveRecord::Base.connection.execute(<<-SQL.squish).first["id"]
        INSERT INTO decidim_consultations_questions (
          decidim_consultation_id,
          decidim_organization_id,
          title,
          subtitle,
          what_is_decided,
          slug,
          "order",
          published_at,
          votes_count,
          created_at,
          updated_at
        ) VALUES (
          #{consultation_id},
          #{organization.id},
          '{"en": "Do you agree?"}'::jsonb,
          '{"en": "Simple question"}'::jsonb,
          '{"en": "We are deciding something important"}'::jsonb,
          'question-1-#{Time.current.to_i}',
          0,
          '#{Time.current}',
          0,
          '#{Time.current}',
          '#{Time.current}'
        )
        RETURNING id;
      SQL
    end

    let!(:response_yes_id) do
      ActiveRecord::Base.connection.execute(<<-SQL.squish).first["id"]
        INSERT INTO decidim_consultations_responses (
          decidim_consultations_questions_id,
          title,
          votes_count,
          created_at,
          updated_at
        ) VALUES (
          #{question_id},
          '{"en": "Yes"}'::jsonb,
          0,
          '#{Time.current}',
          '#{Time.current}'
        )
        RETURNING id;
      SQL
    end

    let!(:response_no_id) do
      ActiveRecord::Base.connection.execute(<<-SQL.squish).first["id"]
        INSERT INTO decidim_consultations_responses (
          decidim_consultations_questions_id,
          title,
          votes_count,
          created_at,
          updated_at
        ) VALUES (
          #{question_id},
          '{"en": "No"}'::jsonb,
          0,
          '#{Time.current}',
          '#{Time.current}'
        )
        RETURNING id;
      SQL
    end

    let!(:vote) do
      ActiveRecord::Base.connection.execute(<<-SQL.squish)
        INSERT INTO decidim_consultations_votes (
          decidim_consultation_question_id,
          decidim_author_id,
          decidim_consultations_response_id,
          created_at,
          updated_at
        ) VALUES (
          #{question_id},
          #{user.id},
          #{response_yes_id},
          '#{Time.current}',
          '#{Time.current}'
        );
      SQL
    end

    it "creates an election with correct attributes" do
      expect do
        task.execute(component_id: component.id.to_s)
      end.to change(Decidim::Elections::Election, :count).by(1)

      election = Decidim::Elections::Election.last
      expect(election.component).to eq(component)
      expect(election.title["en"]).to eq("Simple Consultation")
      expect(election.description["en"]).to eq("All users can vote")
      expect(election.census_manifest).to eq("internal_users")
      expect(election.census_settings).to eq({})
    end

    it "creates questions with correct attributes" do
      expect do
        task.execute(component_id: component.id.to_s)
      end.to change(Decidim::Elections::Question, :count).by(1)

      question = Decidim::Elections::Question.last
      expect(question.body["en"]).to eq("Do you agree?")
      expect(question.description["en"]).to include("We are deciding something important")
      expect(question.position).to eq(0)
    end

    it "creates response options" do
      expect do
        task.execute(component_id: component.id.to_s)
      end.to change(Decidim::Elections::ResponseOption, :count).by(2)

      response_options = Decidim::Elections::ResponseOption.last(2)
      expect(response_options.map { |r| r.body["en"] }).to contain_exactly("Yes", "No")
    end

    it "migrates votes with GlobalID format" do
      expect do
        task.execute(component_id: component.id.to_s)
      end.to change(Decidim::Elections::Vote, :count).by(1)

      vote = Decidim::Elections::Vote.last
      expect(vote.voter_uid).to eq(user.to_global_id.to_s)
      expect(vote.voter_uid).to match(%r{gid://.*/Decidim::User/#{user.id}})
    end

    it "updates vote counts correctly" do
      task.execute(component_id: component.id.to_s)

      question = Decidim::Elections::Question.last
      expect(question.votes_count).to eq(1)

      yes_option = question.response_options.find_by("body->>'en' = ?", "Yes")
      expect(yes_option.votes_count).to eq(1)

      no_option = question.response_options.find_by("body->>'en' = ?", "No")
      expect(no_option.votes_count).to eq(0)
    end
  end

  context "when component does not exist" do
    it "exits with error message" do
      expect do
        task.execute(component_id: "99999")
      end.to raise_error(SystemExit)
    end
  end

  context "when migrating consultation with Setting (delegations_verifier)" do
    let!(:user) { create(:user, organization: organization) }
    let!(:consultation_id) do
      ActiveRecord::Base.connection.execute(<<-SQL.squish).first["id"]
        INSERT INTO decidim_consultations (
          decidim_organization_id,
          title,
          subtitle,
          description,
          slug,
          start_voting_date,
          end_voting_date,
          published_at,
          created_at,
          updated_at
        ) VALUES (
          #{organization.id},
          '{"en": "Consultation with Email Verification"}'::jsonb,
          '{"en": "Requires email verification"}'::jsonb,
          '{"en": "Only participants can vote"}'::jsonb,
          'email-verification-#{Time.current.to_i}',
          '#{Date.current - 30.days}',
          '#{Date.current + 30.days}',
          '#{Time.current}',
          '#{Time.current}',
          '#{Time.current}'
        )
        RETURNING id;
      SQL
    end

    let!(:setting) do
      create(
        :setting,
        organization: organization,
        decidim_consultation_id: consultation_id,
        authorization_method: :email,
        title: { en: "Email Verification Setting" },
        active: true
      )
    end

    let!(:ponderation) do
      create(:ponderation, setting: setting, name: "producer", weight: 2)
    end

    let!(:participant) do
      create(
        :participant,
        setting: setting,
        decidim_user: user,
        email: user.email,
        ponderation: ponderation
      )
    end

    let!(:question_id) do
      ActiveRecord::Base.connection.execute(<<-SQL.squish).first["id"]
        INSERT INTO decidim_consultations_questions (
          decidim_consultation_id,
          decidim_organization_id,
          title,
          subtitle,
          what_is_decided,
          slug,
          "order",
          published_at,
          votes_count,
          created_at,
          updated_at
        ) VALUES (
          #{consultation_id},
          #{organization.id},
          '{"en": "Do you approve?"}'::jsonb,
          '{"en": "Question with email verification"}'::jsonb,
          '{"en": "Important decision"}'::jsonb,
          'question-email-#{Time.current.to_i}',
          0,
          '#{Time.current}',
          0,
          '#{Time.current}',
          '#{Time.current}'
        )
        RETURNING id;
      SQL
    end

    let!(:response_id) do
      ActiveRecord::Base.connection.execute(<<-SQL.squish).first["id"]
        INSERT INTO decidim_consultations_responses (
          decidim_consultations_questions_id,
          title,
          votes_count,
          created_at,
          updated_at
        ) VALUES (
          #{question_id},
          '{"en": "Approve"}'::jsonb,
          0,
          '#{Time.current}',
          '#{Time.current}'
        )
        RETURNING id;
      SQL
    end

    it "creates election with internal_users manifest" do
      task.execute(component_id: component.id.to_s)

      election = Decidim::Elections::Election.last
      expect(election.census_manifest).to eq("internal_users")
    end

    it "includes delegations_verifier in census_settings" do
      task.execute(component_id: component.id.to_s)

      election = Decidim::Elections::Election.last
      expect(election.census_settings["authorization_handlers"]).to have_key("delegations_verifier")
    end

    it "sets setting_id in delegations_verifier options" do
      task.execute(component_id: component.id.to_s)

      election = Decidim::Elections::Election.last
      verifier_options = election.census_settings.dig("authorization_handlers", "delegations_verifier", "options")
      expect(verifier_options["setting"]).to eq(setting.id.to_s)
    end

    it "preserves Setting reference to consultation" do
      task.execute(component_id: component.id.to_s)

      setting.reload
      expect(setting.decidim_consultation_id).to eq(consultation_id)
    end

    context "when running migration twice (idempotency)" do
      it "skips already migrated consultations" do
        # First run
        task.execute(component_id: component.id.to_s)
        first_count = Decidim::Elections::Election.count

        # Second run
        expect do
          task.execute(component_id: component.id.to_s)
        end.not_to change(Decidim::Elections::Election, :count).from(first_count)
      end

      it "does not duplicate votes" do
        # First run
        task.execute(component_id: component.id.to_s)
        first_votes_count = Decidim::Elections::Vote.count

        # Second run
        task.execute(component_id: component.id.to_s)
        expect(Decidim::Elections::Vote.count).to eq(first_votes_count)
      end
    end
  end

  context "when no consultations exist" do
    it "exits with status 0" do
      expect do
        task.execute(component_id: component.id.to_s)
      end.to raise_error(SystemExit) # exits with 0
    end
  end
end
