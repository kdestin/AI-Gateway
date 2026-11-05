import os

from agent_framework import Agent
from agent_framework.foundry import FoundryChatClient
from agent_framework_foundry_hosting import ResponsesHostServer
from azure.identity import DefaultAzureCredential


def main():
    client = FoundryChatClient(
        project_endpoint=os.environ["FOUNDRY_PROJECT_ENDPOINT"],
        model=os.environ["FOUNDRY_MODEL"],
        credential=DefaultAzureCredential(),
    )
    documentation_search = client.get_mcp_tool(
        name="gateway_docs",
        url=os.environ["MCP_SERVER_URL"],
        project_connection_id=os.environ["MCP_PROJECT_CONNECTION_ID"],
        allowed_tools=[os.environ["MCP_TOOL_NAME"]],
        approval_mode="never_require",
    )
    agent = Agent(
        client=client,
        instructions=(
            "For documentation questions, use the documentation search tool once before "
            "answering. Return one relevant documentation URL and keep answers brief."
        ),
        tools=[documentation_search],
        default_options={"store": False},
    )
    ResponsesHostServer(agent).run()


if __name__ == "__main__":
    main()
