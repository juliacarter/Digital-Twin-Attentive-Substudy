#!/bin/bash

# Exit on error
set -e

MAX_PERSONAS=-1
ATTENTIVE_ID="-1"
ATTENTIVE_REVERSE=false
ATTENTIVE_SCALE=-1
RUN_LLM=true

PARSED_ARGUMENTS=$(getopt -a -n run_pipeline --long max_personas:,attentive_id:,attentive_reverse,attentive_scale:,dry_run -- "$@")

eval set -- "$PARSED_ARGUMENTS"
while :
do
    case "$1" in
        --max_personas) MAX_PERSONAS=$2 ; shift 2 ;;
        --attentive_id) ATTENTIVE_ID="$2" ; shift 2 ;;
        --attentive_reverse) ATTENTIVE_REVERSE=true ; shift ;;
        --attentive_scale) ATTENTIVE_SCALE=$2 ; shift 2 ;;
        --dry_run) RUN_LLM=false ; shift ;; 
        --) shift; break ;;
        *) echo "Unexpected option: $1 - this should not happen."
       usage ;;
    esac
done

# Default value for max_personas


# Check if max_personas argument is provided
if [ $# -eq 0 ]; then
    echo "No max_personas provided, using default value: $DEFAULT_MAX_PERSONAS"
    MAX_PERSONAS=$DEFAULT_MAX_PERSONAS
else
    # Support both '5' and '--max_personas=5' as input
    if [[ $1 == --max_personas=* ]]; then
        MAX_PERSONAS="${1#--max_personas=}"
    elif [[ $1 == max_personas=* ]]; then
        MAX_PERSONAS="${1#max_personas=}"
    else
        MAX_PERSONAS="$1"
    fi
fi





# Update the max_personas in the config file
sed -i "s/max_personas: .*/max_personas: $MAX_PERSONAS  # Set to $MAX_PERSONAS for testing/" text_simulation/configs/openai_config.yaml

# Run the pipeline steps
echo "Step 1: Converting personas..."
poetry run python text_simulation/batch_convert_personas.py \
    --persona_json_dir data/mega_persona_json/mega_persona \
    --output_text_dir text_simulation/text_personas \
    --variant full

if ($ATTENTIVE_REVERSE)
then
    echo "Step 2: Converting question JSON to text..."
    poetry run python text_simulation/convert_question_json_to_text.py \
        --attentive_id "$ATTENTIVE_ID" \
        --attentive_reverse \
        --attentive_scale $ATTENTIVE_SCALE
else
    echo "Step 2: Converting question JSON to text..."
    poetry run python text_simulation/convert_question_json_to_text.py \
        --attentive_id "$ATTENTIVE_ID" \
        --attentive_scale $ATTENTIVE_SCALE
fi

echo "Step 3: Creating text simulation input..."
poetry run python text_simulation/create_text_simulation_input.py 

if ($RUN_LLM)
then
    echo "Step 4: Running LLM simulation..."
    poetry run python text_simulation/run_LLM_simulations.py --config text_simulation/configs/attentive_config.yaml --max_personas "$MAX_PERSONAS"
fi

echo "Pipeline completed!" 