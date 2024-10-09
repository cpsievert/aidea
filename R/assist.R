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

  app_dir <- system.file("app", package = "aidea")
  quarto_dir <- file.path(app_dir, "quarto")
  # TODO: do this in a tempdir, not pkg dir
  shiny::addResourcePath("quarto", quarto_dir)
  shiny::addResourcePath("www", file.path(app_dir, "www"))

  saveRDS(data, file.path(quarto_dir, "data.rds"))

  prompt_template <- paste(
    readLines(file.path(app_dir, "prompt.md")),
    collapse = "\n"
  )
  prompt <- glue::glue(prompt_template)

  chat <- elmer::chat_openai(
    system_prompt = prompt,
    api_args = list(temperature = 0),
  )

  quarto_template <- paste(
    readLines(file.path(quarto_dir, "quarto-live-template.qmd")),
    collapse = "\n"
  )

  ui <- page_sidebar(
    shinychat::chat_ui("chat"), # TODO: shinychat doesn't work with dynamic UI
    tags$script(src = "www/helpers.js"),
    title = "EDA with R assistant 🤖",
    sidebar = sidebar(
      open = FALSE,
      position = "right",
      width = "35%",
      style = "height:100%;",
      gap = 0,
      id = "sidebar-repl",
      uiOutput("quarto_live", fill = TRUE),
      actionButton(
        "interpret_editor_results",
        "Interpret results",
        icon = icon("wand-sparkles"),
        disabled = TRUE
      )
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

    observeEvent(editor_code(), {
      bslib::sidebar_toggle("sidebar-repl", open = TRUE)
    })

    output$quarto_live <- renderUI({
      code <- paste(editor_code(), collapse = "\n")
      validate(
        need(
          nzchar(code),
          "No code artifacts created yet. Try asking a question that yield a code suggestion and click the 'Run this code' button."
        )
      )

      quarto_src <- glue::glue(
        quarto_template,
        .open = "$$$",
        .close = "$$$",
      )

      withr::with_dir(quarto_dir, {
        writeLines(quarto_src, "quarto-live.qmd")
        quarto::quarto_render("quarto-live.qmd")
      })

      tags$iframe(
        src = "quarto/quarto-live.html",
        width = "100%",
        height = "400px",
        frameborder = "0",
        class = "html-fill-item"
      )
    })

    observeEvent(input$editor_results, {
      updateActionButton(
        inputId = "interpret_editor_results",
        disabled = FALSE
      )
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
      shinychat::chat_append("chat", stream)
    })
  }

  shinyApp(ui, server)
}