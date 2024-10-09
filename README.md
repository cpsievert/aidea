# aidea

Combine the power of LLMs and R to help guide exploration of a dataset.

DISCLAIMER: This package is a proof of concept and was created for a 2-day hackathon. It will leave many things to be desired, and is not intended for production use.

## Installation

You can install the development version of aidea from GitHub with:

```r
remotes::install_github("cpsievert/aidea")
```

## Usage

This package currently contains just one function, `assist()`, which takes a data frame as input, and provides a chat bot experience tailored for that dataset. Here's an example:

```r
# Load a dataset
data(diamonds, package = "ggplot2")
# Start the aidea app assistant
aidea::assist(diamonds)
```


<img width="1704" alt="Screenshot 2024-10-09 at 6 22 23 PM" src="https://github.com/user-attachments/assets/f9aee57b-4e78-44ce-b9ed-ebec9ead670d">
