$(() => {
  const $usersAnswers = $("#user-answers-summary");
  const path = $usersAnswers.data("summaryPath");
  let $button = $("#consultations-questions-summary-button");
  let $modal = $("#consultations-questions-summary-modal");
  const $div = $(".question-vote-cabin").parent();
  const openModal = (evt) => {
    evt.preventDefault();
    $modal.foundation("open");    
  };

  $button.on("click", openModal);
  let timeout;
  $div.bind("DOMSubtreeModified", function() {
    clearTimeout(timeout);
    timeout = setTimeout(() => {
      $usersAnswers.load(path, () => {
        $button = $usersAnswers.find("#consultations-questions-summary-button");
        $modal = $usersAnswers.find("#consultations-questions-summary-modal");
        $usersAnswers.foundation();
        $button.on("click", openModal);
      });
    }, 300); // Adjust the timeout duration as needed
  });
});
