with langfuse_client.start_as_current_span(name="process-query") as span:
        # Your application code here

        # Create a nested generation span for an LLM call
        with span.start_as_current_observation(
            as_type="generation",
            name="generate-response",
            model="gpt-4",
            input={"query": "Tell me about AI"},
            model_parameters={"temperature": 0.7, "max_tokens": 500}
        ) as generation:
            # Generate response here
            response = "AI is a field of computer science..."

            generation.update(
                output=response,
                usage_details={"prompt_tokens": 10, "completion_tokens": 50},
                cost_details={"total_cost": 0.0023}
            )

            # Score the generation (supports NUMERIC, BOOLEAN, CATEGORICAL)
            generation.score(name="relevance", value=0.95, data_type="NUMERIC")