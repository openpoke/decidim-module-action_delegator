# frozen_string_literal: true

module CustomAutoCompleteSelect
  def custom_autocomplete_select(value, from:)
    within("div[data-autocomplete-for='#{from}']") do
      find(".autocomplete-input").click
      find(".autocomplete-input").native.send_keys(value[0..4])

      dynamic_list_id = find("[id^=autoComplete_list]")[:id]

      expect(page).to have_css("##{dynamic_list_id}") # select should be open now

      expect(page).to have_css("#autoComplete_result_0", text: value)
      find_by_id("autoComplete_result_0", text: value).hover
      expect(page).to have_css("#autoComplete_result_0", text: value)
      find_by_id("autoComplete_result_0", text: value).click
      expect(page).to have_css(".autocomplete__selected-item", text: value)
    end
  end
end
