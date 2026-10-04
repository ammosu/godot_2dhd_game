"""Generate one image with the Codex CLI built-in ImageGen tool.

Usage: python3 tools/art/codex_image.py <prompt.md> <output.png> [reference.png ...]

The prompt file holds the image prompt only; this wrapper adds the instruction to
save the result. References are attached in the order given, so the prompt can
call them image 1, image 2, ... The raw output is copied unchanged to <output.png>;
any cropping or measuring happens in the asset's own build step.
"""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

INSTRUCTION = """Use your built-in image generation tool to create ONE image, then save the resulting PNG file into the current working directory as out.png (copy it from wherever the tool writes it). Do not write code to draw or edit the image; it must come from the image generation tool. Reply only with the saved path.
Image generation prompt{refs}:
"""


def main() -> int:
    prompt_path, output = Path(sys.argv[1]), Path(sys.argv[2]).resolve()
    references = [Path(path).resolve() for path in sys.argv[3:]]
    note = f" (attach the {len(references)} provided image(s) as references, in order)" if references else ""
    prompt = INSTRUCTION.format(refs=note) + prompt_path.read_text()
    with tempfile.TemporaryDirectory() as temp:
        command = ["codex", "exec", "--skip-git-repo-check", "-s", "workspace-write", "-C", temp]
        for reference in references:
            command += ["-i", str(reference)]
        result = subprocess.run(command + ["-"], input=prompt, text=True, capture_output=True)
        produced = Path(temp) / "out.png"
        if result.returncode != 0 or not produced.exists():
            print(f"FAILED ({result.returncode}) {result.stdout[-600:]}{result.stderr[-600:]}")
            return 1
        output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy(produced, output)
    print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
