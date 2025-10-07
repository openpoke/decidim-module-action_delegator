# frozen_string_literal: true

shared_examples "voting in a per question election" do
  it "shows delegation and allows the user vote for himself and the granter" do
    expect(page).to have_css(".election__aside-voted")
    expect(page).to have_content("You have delegated votes.")
    expect(page).to have_content("You can vote on behalf of the following participants in this election:")

    within ".election__aside-voted" do
      expect(page).to have_content(user.name.to_s)
    end

    click_on "Vote"
    expect(page).to have_content("You are voting for yourself (#{delegate_user.name})")

    first("input[value=\"#{response_option1.id}\"]").click
    click_on "Cast vote"

    expect(page).to have_content("Waiting for the next question")

    expect(page).to have_css(".waiting-buttons")
    expect(page).to have_content("You have delegated votes.")
    expect(page).to have_link(
      "Continue voting on behalf of #{user.name}",
      href: election_per_question_vote_path(current_question.id, delegation.id)
    )
    click_on "Continue voting on behalf of #{user.name}"
    expect(page).to have_content("You are voting on behalf of #{user.name}")

    first("input[value=\"#{response_option2.id}\"]").click
    click_on "Cast vote"

    expect(page).to have_content("Your vote has been successfully cast")
    expect(page).to have_link("Edit your vote", href: election_per_question_vote_path(current_question))
    expect(page).to have_link("Edit vote for #{user.name}", href: election_per_question_vote_path(current_question) + "?delegation=#{delegation.id}")

    expect(last_vote(delegate_user).response_option).to eq(response_option1)
    expect(last_vote(user).response_option).to eq(response_option2)

    click_on "Edit vote for #{user.name}"
    first("input[value=\"#{response_option1.id}\"]").click
    click_on "Cast vote"

    expect(page).to have_content("Your vote has been successfully cast")
    expect(last_vote(user).response_option.reload).to eq(response_option1)

    click_on "Edit your vote"
    first("input[value=\"#{response_option2.id}\"]").click
    click_on "Cast vote"

    sleep 0.1 # Wait for the versioning to be saved
    expect(last_vote(delegate_user).response_option.reload).to eq(response_option2)
    expect(last_vote(delegate_user).versions.first.whodunnit).to eq(delegate_user.id.to_s)
    expect(last_vote(delegate_user).versions.first.decidim_action_delegator_delegation_id).to be_blank
    expect(last_vote(user).versions.first.whodunnit).to eq(delegate_user.id.to_s)
    expect(last_vote(user).versions.first.decidim_action_delegator_delegation_id).to eq(delegation.id)
  end

  context "when delegate has voted for delegated user" do
    let!(:next_question) { create(:election_question, :voting_enabled, :with_response_options, election:) }
    let!(:vote1) { create(:election_vote, question: current_question, response_option: current_question.response_options.first, voter_uid: user.to_global_id.to_s) }
    let!(:vote2) { create(:election_vote, question: next_question, response_option: next_question.response_options.first, voter_uid: user.to_global_id.to_s) }

    it "shows voted status on election page" do
      visit election_path
      expect(page).to have_content("You have delegated votes.")
      expect(page).to have_content("You can vote on behalf of the following participants in this election:")

      within all(".election__aside-voted").last do
        expect(page).to have_content("✔ #{user.name}")
      end
    end
  end
end

shared_examples "voting in a normal election" do
  it "shows delegation and allows the user vote for himself and the granter" do
    expect(page).to have_css(".election__aside-voted")
    expect(page).to have_content("You have delegated votes.")
    expect(page).to have_content("Vote on behalf of #{user.name}")

    click_on "Vote"

    first("input[value=\"#{response_option1.id}\"]").click
    click_on "Next"
    sleep 0.1
    first('input[type="radio"], input[type="checkbox"]').click
    click_on "Next"
    click_on "Cast vote"

    expect(page).to have_content("Your vote has been successfully cast")
    click_on "Exit the voting booth"

    expect(page).to have_content("You have already voted.")
    expect(last_vote(delegate_user).response_option).to eq(response_option1)

    click_on "Vote on behalf of #{user.name}"
    expect(page).to have_content("You are voting on behalf of #{user.name}")

    first("input[value=\"#{response_option2.id}\"]").click
    click_on "Next"
    sleep 0.1
    first('input[type="radio"], input[type="checkbox"]').click
    click_on "Next"
    click_on "Cast vote"

    expect(page).to have_content("Your vote has been successfully cast")
    click_on "Exit the voting booth"
    expect(page).to have_content("You have already voted.")

    expect(last_vote(user).response_option.reload).to eq(response_option2)

    click_on "Vote"
    first("input[value=\"#{response_option2.id}\"]").click
    click_on "Next"
    sleep 0.1
    click_on "Next"
    click_on "Cast vote"
    click_on "Exit the voting booth"

    expect(last_vote(delegate_user).reload.response_option).to eq(response_option2)

    click_on "Vote on behalf of #{user.name}"
    first("input[value=\"#{response_option1.id}\"]").click
    click_on "Next"
    sleep 0.1
    click_on "Next"
    click_on "Cast vote"
    click_on "Exit the voting booth"

    expect(last_vote(user).reload.response_option).to eq(response_option1)
    expect(last_vote(delegate_user).versions.first.whodunnit).to eq(delegate_user.id.to_s)
    expect(last_vote(delegate_user).versions.first.decidim_action_delegator_delegation_id).to be_blank
    expect(last_vote(user).versions.first.whodunnit).to eq(delegate_user.id.to_s)
    expect(last_vote(user).versions.first.decidim_action_delegator_delegation_id).to eq(delegation.id)
  end
end

shared_examples "no delegations available" do
  it "does not show delegation buttons" do
    expect(page).to have_no_css(".election__aside-voted")
    expect(page).to have_no_content("You have delegated votes.")
  end
end
