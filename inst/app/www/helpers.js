const chat = document.getElementById('chat');

const observer = new MutationObserver((mutations) => {
  mutations.forEach((mutation) => {
    // Only listen to changes in `.message-content` children
    const target = mutation.target;

    if (!target?.classList.contains('message-content')) {
      return;
    }
    // Get all the code blocks and append a button below each
    // That sends the code to the server as a Shiny input value
    // TODO: automatically determine when the code block is finished 
    // and send the code to the server when that happens
    const els = target.querySelectorAll("pre code");
    els.forEach((el) => {
      if (!hasRunButton(el)) {
        addRunButton(el);
      }
    });

  });
});

function addRunButton(code_el) {
  const button = document.createElement("button");
  button.innerHTML = "Run this code ->";
  button.classList.add("btn", "btn-sm", "btn-default", "run-code");
  function send_editor_code() {
    Shiny.setInputValue("editor_code", code_el.innerText);
  };
  button.onclick = send_editor_code;
  button.style.float = "right";
  // Append the button as a child of the pre block
  code_el.parentNode.appendChild(button);
}

function hasRunButton(code_el) {
  return code_el.parentNode.querySelector(":scope > .run-code") !== null;
}


observer.observe(chat, { childList: true, subtree: true });



window.addEventListener("message", receiveMessage, false);

function receiveMessage(event) {
  Shiny.setInputValue("editor_results", JSON.stringify(event.data));
}