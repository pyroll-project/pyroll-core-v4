set default-list

format:
    treefmt

# build the entire project using pytask optionally filtered by 'key'
build key="":
    uv run pytask build -k "{{ key }}"

clean-dry-run:
    uv run pytask clean --mode dry-run

[confirm("Perform clean?")]
clean-force:
    uv run pytask clean --mode force

[confirm("Perform clean?")]
clean-interactive:
    uv run pytask clean --mode interactive

clean: clean-dry-run clean-force
