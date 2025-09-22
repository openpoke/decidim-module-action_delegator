/* eslint-disable max-params */
document.addEventListener("DOMContentLoaded", () => {
  const watchingDiv = document.querySelector("[data-weight-results-live-update]");
  const questionsContainer = document.querySelector("[data-questions-container]");
  const questionTemplate = document.getElementById("question-0");
  const optionTemplate = document.querySelector("[data-option-template]");
  if (!watchingDiv) {
    return;
  }

  const url = watchingDiv.dataset.weightResultsLiveUpdate;
  const optionVotesPercentTexts = () => document.querySelectorAll("[data-option-votes-percent-text]");
  const optionVotesCountTexts = () => document.querySelectorAll("[data-option-votes-count-text]");
  const optionVotesWidths = () => document.querySelectorAll("[data-option-votes-width]");
  const questionUnweightedCountTexts = () => document.querySelectorAll("[data-question-unweighted-count-text]");
  const questionWeightedCountTexts = () => document.querySelectorAll("[data-question-weighted-count-text]");
  const questionDelegatedCountTexts = () => document.querySelectorAll("[data-question-delegated-count-text]");
  const questionParticipantsCountTexts = () => document.querySelectorAll("[data-question-participants-count-text]");

  const animateText = (element, value) => {
    if (element.textContent === value) {
      return;
    }
    element.textContent = value;
    element.classList.add("live_results-number_changing");
    setTimeout(() => {
      element.classList.remove("live_results-number_changing");
    }, 1000);
  };

  const digOptionValue = (data, questionId, optionId, ponderationId, key) => {
    data.questions = data.questions || [];
    const question = data.questions.find((item) => item.id === parseInt(questionId, 10));
    if (!question) {
      return null;
    }
    const responseOptions = question.response_options || [];
    if (!Array.isArray(responseOptions)) {
      return null;
    }
    const option = responseOptions.find((item) => {
      if (ponderationId) {
        return item.id === parseInt(optionId, 10) && item.ponderation_id === parseInt(ponderationId, 10);
      }
      return item.id === parseInt(optionId, 10);
    });
    // console.log("Digging option:", questionId, optionId, ponderationId, option);
    if (!option) {
      return null;
    }
    if (key in option) {
      return option[key];
    }
    return null;
  };

  const createAdditionalQuestions = (data) => {
    if (!questionTemplate || !questionsContainer || !optionTemplate) {
      return;
    }
    const questions = data.questions || [];
    const additionalQuestions = questions.filter((question) => !document.getElementById(`question-${question.id}`) && question.published_results);
    additionalQuestions.forEach((question) => {
      const questionElement = questionTemplate.cloneNode(true);
      questionElement.id = `question-${question.id}`;
      questionElement.classList.remove("hidden");
      questionElement.querySelector("[data-question-body]").textContent = question.body;
      const optionsContainer = questionElement.querySelector("[data-options-container]");
      question.response_options.forEach((option) => {
        const optionElement = optionTemplate.cloneNode(true);
        optionElement.classList.remove("hidden");
        optionElement.querySelector("[data-option-body]").textContent = option.body;
        optionElement.querySelector("[data-option-votes-count-text").dataset.optionVotesCountText = `${question.id},${option.id}`;
        optionElement.querySelector("[data-option-votes-percent-text").dataset.optionVotesPercentText = `${question.id},${option.id}`;
        optionElement.querySelector("[data-option-votes-width").dataset.optionVotesWidth = `${question.id},${option.id}`;
        optionsContainer.appendChild(optionElement);
      });
      questionsContainer.appendChild(questionElement);
        
    });
  };
  const fetchResults = async () => {
    try {
      const response = await fetch(url, {
        method: "GET",
        headers: {
          "Accept": "application/json", 
          "Content-Type": "application/json",
          "X-Requested-With": "XMLHttpRequest"
        }
      });
      if (!response.ok) {
        throw new Error("Network response was not ok");
      }
      const data = await response.json();
      // console.log("Fetched data:", data);

      createAdditionalQuestions(data);
      optionVotesCountTexts().forEach((el) => {
        const [questionId, optionId, ponderationId] = el.dataset.optionVotesCountText.split(",");
        console.log("Updating count text for:", questionId, optionId, ponderationId);
        const val = digOptionValue(data, questionId, optionId, ponderationId, "votes_count_text")
        if (val) {
          animateText(el, val);
        }
      });
      optionVotesPercentTexts().forEach((el) => {
        const [questionId, optionId, ponderationId] = el.dataset.optionVotesPercentText.split(",");
        const val = digOptionValue(data, questionId, optionId, ponderationId, "votes_percent_text")
        if (val) {
          animateText(el, val);
        }
      });
      optionVotesWidths().forEach((el) => {
        const [questionId, optionId, ponderationId] = el.dataset.optionVotesWidth.split(",");
        const val = digOptionValue(data, questionId, optionId, ponderationId, "votes_percent")
        if (val) {
          el.style.width = `${val}%`;
        }
      });
      questionUnweightedCountTexts().forEach((el) => {
        const questionId = el.dataset.questionUnweightedCountText;
        const question = data.questions.find((item) => item.id === parseInt(questionId, 10));
        if (question && question.unweighted_votes_text) {
          animateText(el, question.unweighted_votes_text);
        }
      });
      questionWeightedCountTexts().forEach((el) => {
        const questionId = el.dataset.questionWeightedCountText;
        const question = data.questions.find((item) => item.id === parseInt(questionId, 10));
        if (question && question.weighted_votes_text) {
          animateText(el, question.weighted_votes_text);
        }
      });
      questionDelegatedCountTexts().forEach((el) => {
        const questionId = el.dataset.questionDelegatedCountText;
        const question = data.questions.find((item) => item.id === parseInt(questionId, 10));
        if (question && question.delegated_votes_text) {
          animateText(el, question.delegated_votes_text);
        }
      });
      questionParticipantsCountTexts().forEach((el) => {
        const questionId = el.dataset.questionParticipantsCountText;
        const question = data.questions.find((item) => item.id === parseInt(questionId, 10));
        if (question && question.participants_text) {
          animateText(el, question.participants_text);
        }
      });

      // repeat for ongoing elections only
      if (data.ongoing) {
        setTimeout(fetchResults, 4000);
      }
    } catch (error) {
      console.error("Error fetching results:", error);
    }
  };

  fetchResults();
});