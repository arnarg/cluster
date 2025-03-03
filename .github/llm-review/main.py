import pathlib
import sys
import os
import openai

BASE_URL = "https://api.hyperbolic.xyz/v1"


def get_sys_prompt() -> str:
    dir = pathlib.Path(__file__).parent.resolve()

    with open(f"{dir}/prompt.md", "r") as stream:
        return stream.read()


def do_completion(api_key: str, system: str, prompt: str):
    client = openai.OpenAI(
        base_url=BASE_URL,
        api_key=api_key,
    )

    completion = client.chat.completions.create(
        model="deepseek-ai/DeepSeek-R1",
        temperature=0.1,
        max_tokens=4096,
        messages=[
            {
                "role": "system",
                "content": system,
            },
            {
                "role": "user",
                "content": prompt,
            },
        ],
    )

    response = completion.choices[0].message.content

    # DeepSeek-R1 outputs <think>...</think> in the
    # start of the content.
    # I split the string on </think> and take the
    # last element to effectively discard the thinking.
    parts = response.split("</think>")
    if len(parts) > 0:
        return parts[-1]

    # Otherwise we just return the response
    return response


def print_result(result: str):
    if (
        os.environ.get("GITHUB_ACTIONS") == "true"
        and os.environ.get("GITHUB_OUTPUT") is not None
    ):
        with open(os.environ.get("GITHUB_OUTPUT"), "a") as output:
            output.write("review<<EOF\n")
            output.write(result + "\n")
            output.write("EOF\n")
    else:
        print(result)


if __name__ == "__main__":
    api_key = os.environ["HYPERBOLIC_API_KEY"]

    diff = sys.stdin.read()

    sys_prompt = get_sys_prompt()

    md = do_completion(api_key, sys_prompt, diff)

    print_result(md)
