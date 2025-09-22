# frozen_string_literal: true

require "spec_helper"

# We make sure that the checksum of the file overriden is the same
# as the expected. If this test fails, it means that the overriden
# file should be updated to match any change/bug fix introduced in the core
module Decidim::ActionDelegator
  checksums = [
    package: "decidim-elections",
    files: {
      "/app/controllers/decidim/elections/votes_controller.rb" => "7186de422abdd04301afebe31e5fe409",
      "/app/controllers/decidim/elections/per_question_votes_controller.rb" => "e14f616d3b0d10d14747f416a8e86f5e",
      "/app/views/decidim/elections/votes/receipt.html.erb" => "e3e0436cf1e8fdf6f5d3ea6b448d3d59",
      "/app/views/decidim/elections/per_question_votes/waiting.html.erb" => "ba81dc5d2961d1402f5a381d99a19093",
      "/app/views/decidim/elections/per_question_votes/show.html.erb" => "d73ad2b911d0f1312cab94816b0e4aee",
      "/app/views/decidim/elections/elections/_election_aside.html.erb" => "5dcddd4851780cbedbe3f8fe90a04812",
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
