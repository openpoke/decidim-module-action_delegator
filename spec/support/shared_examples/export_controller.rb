# frozen_string_literal: true

# RSpec.shared_examples "results export controller" do |type|
#   it "authorizes the action" do
#     expect(controller).to receive(:allowed_to?)
#       .with(:export_consultation_results, :consultation, { consultation: consultation })
#
#     post :create, params: { consultation_slug: consultation.slug }
#   end
#
#   it "enqueues a ExportConsultationResultsJob" do
#     expect(Decidim::ActionDelegator::ExportConsultationResultsJob)
#       .to receive(:perform_later)
#       .with(user, consultation, type)
#
#     post :create, params: { consultation_slug: consultation.slug }
#   end
#
#   it "redirects back" do
#     request.env["HTTP_REFERER"] = "http://#{request.host}/referer"
#     post :create, params: { consultation_slug: consultation.slug }
#
#     expect(response).to redirect_to("/referer")
#   end
#
#   it "returns a flash notice" do
#     post :create, params: { consultation_slug: consultation.slug }
#     expect(flash[:notice]).to eq(I18n.t("decidim.admin.exports.notice"))
#   end
# end
