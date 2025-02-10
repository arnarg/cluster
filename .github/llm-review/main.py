import sys
import os
import re
import openai

BASE_URL = "https://api.hyperbolic.xyz/v1"

SYSTEM_PROMPT = """
You're reviewing a pull request change.
Point out any potential issues that could arise from this changed being merged.
Do not assume that anyone has verified that the changes work.
In case of version changes, try to include a link to release notes.
You're only concerned with changes to Kubernetes manifests in the `manifests/` folder.
Don't ask any questions.
"""


def parse_content(content: str):
    regex = r"<think>(.*)<\/think>(.*)"
    m = re.findall(regex, content, flags=re.DOTALL)
    if m and m[0]:
        thinking = m[0][0].strip()
        response = m[0][1].strip()
        return {
            "thinking": thinking,
            "response": response,
        }
    else:
        raise Exception(f"Could not parse the response: {content}")


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

    return parse_content(response)


def do_review(api_key: str, diff: str):
    PROMPT = f"""```diff
{diff}
```"""

    content = do_completion(api_key, SYSTEM_PROMPT, PROMPT)

    return f"""{content["response"]}

<details>
  <summary>My thinking</summary>

  > {'  > '.join(content["thinking"].splitlines(True))}
</details>"""


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

    md = do_review(api_key, diff)

    print_result(md)
