# frozen_string_literal: true

require "spec_helper"

# We make sure that the checksum of the file overriden is the same
# as the expected. If this test fails, it means that the overriden
# file should be updated to match any change/bug fix introduced in the core
module Decidim::ActionDelegator
  checksums = [
    package: "decidim-elections",
    files: {
      "/app/controllers/decidim/elections/votes_controller.rb" => "53a611d2a456e2032b986a76cdcf6bf1",
      "/app/controllers/decidim/elections/per_question_votes_controller.rb" => "fa6a7d89d010bbe8faa02d3e89c94d43",
      "/app/views/decidim/elections/votes/receipt.html.erb" => "ce9357487afe0f6b6ad9779ad0a64151",
      "/app/views/decidim/elections/per_question_votes/waiting.html.erb" => "ba81dc5d2961d1402f5a381d99a19093",
      "/app/views/decidim/elections/per_question_votes/show.html.erb" => "5b0cd91877704f8211307ed220006421",
      "/app/views/decidim/elections/elections/_election_aside.html.erb" => "5340fc308768898b8ccdaab00d9d9a52",
      "/app/views/decidim/elections/admin/dashboard/_results.html.erb" => "af377ab1ea832fb15f211a2ea2efa361",
      "/app/views/decidim/elections/elections/_vote_results.html.erb" => "c53443fa9a623cb366925ffe03449321"
    }
  ]

  describe "Overriden files", type: :view do
    checksums.each do |item|
      # rubocop:disable Rails/DynamicFindBy
      spec = ::Gem::Specification.find_by_name(item[:package])
      # rubocop:enable Rails/DynamicFindBy
      item[:files].each do |file, signature|
        it "#{spec.gem_dir}#{file} matches checksum" do
          expect(md5("#{spec.gem_dir}#{file}")).to eq(signature)
        end
      end
    end

    private

    def md5(file)
      Digest::MD5.hexdigest(File.read(file))
    end
  end
end
