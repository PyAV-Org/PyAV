import warnings

from av import deprecation


def test_method() -> None:
    class Example:
        def __init__(self, x: int = 100) -> None:
            self.x = x

        @deprecation.method
        def foo(self, a: int, b: int) -> int:
            return self.x + a + b

    obj = Example()

    with warnings.catch_warnings(record=True) as captured:
        assert obj.foo(20, b=3) == 123
        assert "Example.foo is deprecated" in str(captured[0].message)


def test_renamed_attr() -> None:
    class Example:
        new_value = "foo"
        old_value = deprecation.renamed_attr("new_value")

        def new_func(self, a: int, b: int) -> int:
            return a + b

        old_func = deprecation.renamed_attr("new_func")

    obj = Example()

    with warnings.catch_warnings(record=True) as captured:
        assert obj.old_value == "foo"
        assert "Example.old_value is deprecated" in str(captured[0].message)

        obj.old_value = "bar"
        assert "Example.old_value is deprecated" in str(captured[1].message)

    with warnings.catch_warnings(record=True) as captured:
        assert obj.old_func(1, 2) == 3
        assert "Example.old_func is deprecated" in str(captured[0].message)
