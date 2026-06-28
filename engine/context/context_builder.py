class ContextBuilder:
    def __init__(self, token_budget=4000):
        self.token_budget = token_budget

    def assemble_context(self, retrieval_results):
        # Logic to assemble context respecting the token budget
        context = ""  # Placeholder for context assembly logic
        return context[:self.token_budget]  # Ensure we do not exceed the token budget
