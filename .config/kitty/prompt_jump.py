# Ctrl+Up/Down (see kitty.conf): jump to the previous/next shell prompt, as Ghostty and VS Code do. In a full-screen
# program (on the alternate screen, which has no shell prompts), pass the key on instead, e.g. for Claude Code to jump
# between my prompts (see its prompt-jump mod).
#
# Usage: `kitten prompt_jump.py up|down`, from a kitty.conf mapping

from kittens.tui.handler import result_handler


def main(args: list[str]) -> None:
    pass


@result_handler(no_ui=True)
def handle_result(args: list[str], answer: None, target_window_id: int, boss) -> None:
    window = boss.window_id_map.get(target_window_id)
    if window is None:
        return
    direction = args[1]
    if window.screen.is_main_linebuf():
        window.scroll_to_prompt(-1 if direction == 'up' else 1)
    else:
        window.send_key(f'ctrl+{direction}')
