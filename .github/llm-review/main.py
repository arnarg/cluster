import os
import re
import openai
import requests

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


def get_diff(repo: str, id: str):
    url = f"https://github.com/{repo}/pull/{id}.diff"

    res = requests.get(url)

    if res.status_code != 200:
        raise Exception(f"Unexpected status code {res.status_code}: {res.text}")

    return res.text


def create_comment(repo: str, token: str, id: str, body: str):
    url = f"https://api.github.com/repos/{repo}/issues/{id}/comments"

    headers = {
        "Accept": "application/vnd.github+json",
        "Authorization": f"Bearer {token}",
        "X-GitHub-Api-Version": "2022-11-28",
    }

    payload = {
        "body": body,
    }

    res = requests.post(url, headers=headers, json=payload)

    if res.status_code != 201:
        raise Exception(f"Unexpected status code {res.status_code}: {res.text}")


if __name__ == "__main__":
    repo = os.environ["GITHUB_REPOSITORY"]
    pr_id = os.environ["GITHUB_PR_ID"]
    token = os.environ["GITHUB_TOKEN"]
    api_key = os.environ["HYPERBOLIC_API_KEY"]

    diff = get_diff(repo, pr_id)

    md = do_review(api_key, diff)

    create_comment(repo, token, pr_id, md)
