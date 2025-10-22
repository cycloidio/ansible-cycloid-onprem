export YAMLFIX_SEQUENCE_STYLE := "keep_style"
export YAMLFIX_quote_basic_values := "true"
export YAMLFIX_quote_representation := '"'
export YAMLFIX_INDENT_MAPPING := "2"
export YAMLFIX_INDENT_OFFSET := "0"
export YAMLFIX_INDENT_SEQUENCE := "2"
export YAMLFIX_WHITELINES := "1"
export YAMLFIX_SECTION_WHITELINES := "1"
export YAMLFIX_LINE_LENGTH := "10000"

format:
    #! /usr/bin/env bash
    for f in $(find . -name "*.yml" -type f); do
      echo "fixing: ${f}"
      yamlfix "$f" || true
    done
