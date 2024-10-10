#' @import shiny
#' @import bslib
#' @import shinychat
#' @import elmer
#' @import quarto
#' @import glue
#' @import jsonlite
#' @import withr
NULL

#' Launch the AI-powered EDA assistant
#' 
#' @param data A data frame.
#' 
#' @export 
#' @examples
#' 
#' data(diamonds, package = "ggplot2")
#' assist(diamonds)
assist <- function(data) {
  data_name <- as.character(substitute(data))

  # Directory holding assets for the app
  app_dir <- system.file("app", package = "aidea")

  # Get the prompt and start the chat
  prompt_template <- paste(
    readLines(file.path(app_dir, "prompt.md")),
    collapse = "\n"
  )
  prompt <- glue::glue(prompt_template)

  chat <- elmer::chat_openai(
    system_prompt = prompt,
    api_args = list(temperature = 0),
  )

  # Make JS/CSS assets available
  shiny::addResourcePath("www", file.path(app_dir, "www"))

  # For the Quarto portion, set up a tempdir where the 
  # doc will render and supporting files will live
  user_dir <- tempfile()
  dir.create(user_dir)
  on.exit(unlink(user_dir), add = TRUE)
  
  # Make the data available to the Quarto doc
  saveRDS(data, file.path(user_dir, "data.rds"))

  # Copy quarto extensions over to the user dir (for rendering)
  quarto_dir <- file.path(app_dir, "quarto")
  file.copy(
    file.path(quarto_dir, "_extensions"),
    user_dir,
    recursive = TRUE,
    overwrite = TRUE
  )
  # Grab the quarto template (which will be filled in with code suggestions)
  quarto_template <- paste(
    readLines(file.path(quarto_dir, "quarto-live-template.qmd")),
    collapse = "\n"
  )
  # Need to make the Quarto assets available for the iframe
  shiny::addResourcePath("quarto-assets", user_dir)

  ui <- page_sidebar(
    shinychat::chat_ui("chat"), # TODO: shinychat doesn't work with dynamic UI
    tags$script(src = "www/helpers.js"),
    div(
      class = "offcanvas offcanvas-start",
      tabindex = "-1",
      id = "offcanvas-interpret",
      "data-bs-scroll" = "true",
      div(
        class = "offcanvas-header",
        uiOutput("interpret_title"),
        tags$button(
          type = "button",
          class = "btn-close",
          `data-bs-dismiss` = "offcanvas",
          `aria-label` = "Close"
        )
      ),
      div(
        class = "offcanvas-body",
        tags$style("#offcanvas-interpret shiny-chat-input {display: none;}"),
        shinychat::chat_ui("chat_interpret")
      )
    ),
    title = "EDA with R assistant 🤖",
    sidebar = sidebar(
      open = FALSE,
      position = "right",
      width = "35%",
      style = "height:100%;",
      gap = 0,
      id = "sidebar-repl",
      uiOutput("editor", fill = TRUE),
      actionButton(
        "interpret_editor_results",
        "Interpret results",
        icon = icon("wand-sparkles"),
        disabled = TRUE,
        "data-bs-toggle" = "offcanvas",
        "data-bs-target" = "#offcanvas-interpret",
        "aria-controls" = "offcanvas-interpret"
      )
    ),
    theme = bslib::bs_theme(
      "offcanvas-horizontal-width" = "600px",
      "offcanvas-backdrop-opacity" = 0
    )
  )

  server <- function(input, output, session) {
    # Welcome message for the chat
    init_response <- chat$stream_async(
      paste("Tell me about the", data_name, "dataset")
    )
    shinychat::chat_append("chat", init_response)

    # When input is submitted, append to chat, and create artifact buttons
    observeEvent(input$chat_user_input, {
      stream <- chat$stream_async(
        input$chat_user_input,
        !!!lapply(input$file, elmer::content_image_file)
      )
      shinychat::chat_append("chat", stream)
    })

    editor_code <- reactive({
      input$editor_code
    })

    interpret_title <- reactiveVal(NULL)

    observeEvent(editor_code(), {
      bslib::sidebar_toggle("sidebar-repl", open = TRUE)

      res <- chat$chat(
        "I've selected the following code to run in an R console.",
        paste("```r", editor_code(), "```"),
        "Provide to me a short summary title capturing the main idea of this code does. ",
        "It'll get used in the UI so that the user can refer back to it later.",
        "Don't bother with putting a Title: prefix or markdown formatting, just the title."
      )

      interpret_title(as.character(res))
    })

    output$interpret_title <- renderUI({
      req(interpret_title())
      tags$h5(interpret_title())
    })

    output$editor <- renderUI({
      code <- paste(editor_code(), collapse = "\n")
      validate(
        need(
          nzchar(code),
          "No code suggestions made yet. Try asking a question that produces a code suggestion and click the 'Run this code' button."
        )
      )

      quarto_src <- glue::glue(
        quarto_template,
        .open = "$$$",
        .close = "$$$",
      )

      withr::with_dir(user_dir, {
        writeLines(quarto_src, "quarto-live.qmd")
        quarto::quarto_render("quarto-live.qmd")
      })

      tags$iframe(
        src = "quarto-assets/quarto-live.html",
        width = "100%",
        height = "400px",
        frameborder = "0",
        class = "html-fill-item"
      )
    })

    results_have_interpretation <- reactiveVal(FALSE)

    observeEvent(editor_results(), {
      updateActionButton(
        inputId = "interpret_editor_results",
        disabled = FALSE
      )
      results_have_interpretation(FALSE)
    })

    editor_results <- reactive({
      req(input$editor_results)
      results <- jsonlite::fromJSON(input$editor_results, simplifyDataFrame = FALSE)
      lapply(results, function(x) {
        if (x$type == "image") {
          elmer::content_image_url(x$content)
        } else if (x$type == "text") {
          x$content
        } else {
          x
        }
      })
    })

    observeEvent(input$interpret_editor_results, {

      if (results_have_interpretation()) {
        return()
      }

      results_have_interpretation(TRUE)

      # TODO: shinychat needs a way to clear the chat
      shiny::removeUI(
        selector = "#chat_interpret shiny-chat-message",
        multiple = TRUE,
      )

      chat_input <- rlang::list2(
        "The following code:",
        "```r",
        editor_code(),
        "```",
        "Has created the following results:",
        !!!editor_results(),
        "Interpret these results, and offer suggestions for next steps."
      )

      stream <- chat$stream_async(!!!chat_input)

      shinychat::chat_append(
        "chat_interpret", 
        stream
      )
    })
  }

  shinyApp(ui, server)
}