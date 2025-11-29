#!/bin/bash

# Exit on error
set -e


MAX_PERSONAS=-1
ATTENTIVE_ID="-1"
ATTENTIVE_REVERSE=false
ATTENTIVE_SCALE=-1
RUN_LLM=true

PARSED_ARGUMENTS=$(getopt -a -n run_pipeline -o '' --long max_personas:,attentive_id:,attentive_reverse,attentive_scale:,dry_run -- "$@")

echo "PARSED_ARGUMENTS is $PARSED_ARGUMENTS"
eval set -- "$PARSED_ARGUMENTS"
while :
do
    case "$1" in
        --attentive_id) ATTENTIVE_ID="$2" ; shift 2 ;;
        --max_personas) MAX_PERSONAS=$2 ; shift 2 ;;
        --attentive_reverse) ATTENTIVE_REVERSE=true ; shift ;;
        --attentive_scale) ATTENTIVE_SCALE=$2 ; shift 2 ;;
        --dry_run) RUN_LLM=false ; shift ;; 
        --) shift; break ;;
        *) echo "Unexpected option: $1 - this should not happen."
       usage ;;
    esac
done

# Default value for max_personas


echo "$ATTENTIVE_ID"
echo "$MAX_PERSONAS"


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

echo "$MAX_PERSONAS"

if ($RUN_LLM)
then
    echo "Step 4: Running LLM simulation..."
    poetry run python text_simulation/run_LLM_simulations.py --config text_simulation/configs/openai_config.yaml --max_personas "$MAX_PERSONAS"
fi

echo "Pipeline completed!" 