# aidea

Combine the power of LLMs and R to help guide exploration of a dataset.

DISCLAIMER: This package is a proof of concept and was created for a 2-day hackathon. It's currently just a fun side project. Don't use it for anything serious.

## Installation

You can install the development version of aidea from GitHub with:

```r
remotes::install_github("cpsievert/aidea")
```

## Prerequisites

To use this package, you'll also need credentials for the LLM that powers `assist()`.

By default, `assist()` uses OpenAI, so you'll need to set an environment variable named `OPENAI_API_KEY` using the key from https://platform.openai.com/account/api-keys

We recommend setting that variable via `usethis::edit_r_environ()`. See [`{ellmer}`](https://github.com/hadley/ellmer/?tab=readme-ov-file#prerequisites)'s prerequisites if you plan on using a different model.

## Usage

This package currently contains just one function, `assist()`, which takes a data frame as input, and provides a chat bot experience tailored for that dataset:

```r
# Load a dataset
data(diamonds, package = "ggplot2")
# Start the aidea app assistant
aidea::assist(diamonds)
```

You'll be welcomed with overview of what's in the data (e.g., interesting summary stats, variable types, etc) as well as some questions to ask about the data.

<img width="1300" alt="Screenshot 2024-10-10 at 12 57 51 PM" src="https://github.com/user-attachments/assets/772ae0b0-692b-4ee2-af6e-327e2b1ec7a9">

<br/>

When you ask a question about the data, it'll offer R code to assist in answering that question.

That R code will include an option to run the code in browser:

<img width="1299" alt="Screenshot 2024-10-10 at 12 58 34 PM" src="https://github.com/user-attachments/assets/db73d8e0-fbde-4820-9117-65c819bf5dbc">

<br/>

When clicked, the code is run in a sidebar, and results displayed below the interactive code editor.

<img width="1303" alt="Screenshot 2024-10-10 at 12 59 07 PM" src="https://github.com/user-attachments/assets/9e801ac3-3cdf-4404-a6ee-b7d3e7724e70">

When you're unsure of how to interpret the results, press the interpret button. This will open an additional sidebar with an interpretation of the current results:

<img width="1302" alt="Screenshot 2024-10-10 at 12 59 43 PM" src="https://github.com/user-attachments/assets/3a889e50-0585-4b82-9128-85b1f6c168f0">


## How does it work?

This package uses a combination of [`{ellmer}`](https://github.com/hadley/ellmer) and [`{shinychat}`](https://github.com/jcheng5/shinychat/) to provide the LLM assisted chatbot experience. 
It **does not** send all of your data to the LLM, just basic summary stats (e.g., number of rows/columns) and data characteristics (e.g., variable types). 
It will, however, send any results you choose to interpret to the LLM.
If you are worried about privacy, consider using a local model (i.e., `assist(chat = ellmer::chat_ollama())`) instead of OpenAI
