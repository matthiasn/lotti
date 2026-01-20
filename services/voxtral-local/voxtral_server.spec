# -*- mode: python ; coding: utf-8 -*-

block_cipher = None

a = Analysis(
    ['main.py'],
    pathex=[],
    binaries=[],
    datas=[],
    hiddenimports=[
        # Uvicorn
        'uvicorn.logging',
        'uvicorn.loops',
        'uvicorn.loops.auto',
        'uvicorn.protocols',
        'uvicorn.protocols.http',
        'uvicorn.protocols.http.auto',
        'uvicorn.protocols.websockets',
        'uvicorn.protocols.websockets.auto',
        'uvicorn.lifespan',
        'uvicorn.lifespan.on',
        # FastAPI/Pydantic
        'fastapi',
        'pydantic',
        'pydantic_core',
        # PyTorch
        'torch',
        'torch.utils',
        'torch.utils.data',
        'torchaudio',
        # Transformers
        'transformers',
        'transformers.pipelines',
        'transformers.pipelines.base',
        'transformers.models.auto',
        'transformers.generation',
        # Mistral tokenizer
        'mistral_common',
        'mistral_common.tokens',
        # Audio processing
        'librosa',
        'librosa.core',
        'librosa.util',
        'soundfile',
        'pydub',
        'audioread',
        # Numeric
        'numpy',
        'numpy.typing',
        # HuggingFace Hub
        'huggingface_hub',
        # System
        'psutil',
        'dotenv',
        # Local modules
        'config',
        'model_manager',
        'audio_processor',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        # Exclude test dependencies to reduce size
        'pytest',
        'pytest_asyncio',
        'httpx',
    ],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='voxtral_server',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
