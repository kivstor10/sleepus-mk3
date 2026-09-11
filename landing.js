(() => {
  "use strict";

  const WAITLIST_ENDPOINT = "/api/waitlist";
  const form = document.querySelector("#waitlistForm");
  const email = document.querySelector("#email");
  const submitButton = document.querySelector("#submitButton");
  const message = document.querySelector("#formMessage");
  const successCard = document.querySelector("#successCard");

  async function submitWaitlistEmail(address) {
    const response = await fetch(WAITLIST_ENDPOINT, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: address })
    });
    if (!response.ok) throw new Error("Unable to join the waitlist right now. Please try again.");
    return response.json().catch(() => ({}));
  }

  form.addEventListener("submit", async event => {
    event.preventDefault();
    message.textContent = "";
    if (!email.checkValidity()) {
      email.reportValidity();
      return;
    }

    submitButton.disabled = true;
    submitButton.textContent = "Joining waitlist...";
    try {
      await submitWaitlistEmail(email.value.trim());
      form.hidden = true;
      successCard.hidden = false;
    } catch (error) {
      message.textContent = error.message || "Unable to join the waitlist right now. Please try again.";
      submitButton.disabled = false;
      submitButton.textContent = "Join Batch 1 Waitlist";
    }
  });

  window.submitWaitlistEmail = submitWaitlistEmail;
})();