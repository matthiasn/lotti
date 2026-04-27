
# Run Qwen3.6-35B-A3B-8bit locally

On macOS this works:

```
$ uv venv --python 3.12 .venv-vlm
$ source .venv-vlm/bin/activate
$ uv pip install --upgrade mlx-vlm
$ python -m mlx_vlm.server --model mlx-community/Qwen3.6-35B-A3B-8bit --port 8000
```

