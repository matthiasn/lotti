"""Root conftest for the matrix provisioning service.

`pytest_plugins` is only honoured in the rootdir conftest — declaring it in
`tests/conftest.py` is deprecated and errors on newer pytest, because that file
is not the run root once `pytest.ini` sits here.
"""

pytest_plugins = ["pytest_asyncio"]
