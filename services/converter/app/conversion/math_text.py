import re

_SUPERSCRIPT_MAP = str.maketrans(
    {
        "0": "⁰",
        "1": "¹",
        "2": "²",
        "3": "³",
        "4": "⁴",
        "5": "⁵",
        "6": "⁶",
        "7": "⁷",
        "8": "⁸",
        "9": "⁹",
        "+": "⁺",
        "-": "⁻",
        "=": "⁼",
        "(": "⁽",
        ")": "⁾",
        "a": "ᵃ",
        "b": "ᵇ",
        "c": "ᶜ",
        "d": "ᵈ",
        "e": "ᵉ",
        "f": "ᶠ",
        "g": "ᵍ",
        "h": "ʰ",
        "i": "ⁱ",
        "j": "ʲ",
        "k": "ᵏ",
        "l": "ˡ",
        "m": "ᵐ",
        "n": "ⁿ",
        "o": "ᵒ",
        "p": "ᵖ",
        "r": "ʳ",
        "s": "ˢ",
        "t": "ᵗ",
        "u": "ᵘ",
        "v": "ᵛ",
        "w": "ʷ",
        "x": "ˣ",
        "y": "ʸ",
        "z": "ᶻ",
    }
)
_SUBSCRIPT_MAP = str.maketrans(
    {
        "0": "₀",
        "1": "₁",
        "2": "₂",
        "3": "₃",
        "4": "₄",
        "5": "₅",
        "6": "₆",
        "7": "₇",
        "8": "₈",
        "9": "₉",
        "+": "₊",
        "-": "₋",
        "=": "₌",
        "(": "₍",
        ")": "₎",
        "a": "ₐ",
        "e": "ₑ",
        "h": "ₕ",
        "i": "ᵢ",
        "j": "ⱼ",
        "k": "ₖ",
        "l": "ₗ",
        "m": "ₘ",
        "n": "ₙ",
        "o": "ₒ",
        "p": "ₚ",
        "r": "ᵣ",
        "s": "ₛ",
        "t": "ₜ",
        "u": "ᵤ",
        "v": "ᵥ",
        "x": "ₓ",
    }
)
_GREEK_REPLACEMENTS = {
    "alpha": "α",
    "beta": "β",
    "gamma": "γ",
    "delta": "δ",
    "epsilon": "ε",
    "varepsilon": "ε",
    "theta": "θ",
    "lambda": "λ",
    "mu": "μ",
    "nu": "ν",
    "pi": "π",
    "rho": "ρ",
    "sigma": "σ",
    "tau": "τ",
    "phi": "φ",
    "varphi": "φ",
    "omega": "ω",
    "Delta": "Δ",
    "Gamma": "Γ",
    "Sigma": "Σ",
    "Omega": "Ω",
}
_SYMBOL_REPLACEMENTS = {
    "cdot": "·",
    "times": "×",
    "leq": "≤",
    "le": "≤",
    "geq": "≥",
    "ge": "≥",
    "neq": "≠",
    "approx": "≈",
    "sim": "∼",
    "infty": "∞",
    "pm": "±",
    "mp": "∓",
    "sum": "∑",
    "prod": "∏",
    "mid": "|",
    "vert": "|",
    "lVert": "‖",
    "rVert": "‖",
    "to": "→",
    "rightarrow": "→",
    "leftarrow": "←",
    "dots": "…",
    "dotsc": "…",
    "ldots": "…",
}


def normalize_readable_math_fragments(text: str) -> str:
    normalized = re.sub(
        r"sqrt\([^()]+\)",
        lambda match: latex_to_readable_math_text(match.group(0)),
        text,
    )
    normalized = re.sub(
        r"\b\d+\^\([^)]+\)",
        lambda match: latex_to_readable_math_text(match.group(0)),
        normalized,
    )
    normalized = re.sub(
        r"\b\d+\^[A-Za-z0-9+\-=]+",
        lambda match: latex_to_readable_math_text(match.group(0)),
        normalized,
    )
    for _ in range(2):
        normalized = re.sub(
            r"(?<![A-Za-z0-9])(?:[A-Za-z]+|[\u0370-\u03ff])_[A-Za-z0-9+\-=]+",
            lambda match: latex_to_readable_math_text(match.group(0)),
            normalized,
        )
    return _replace_bare_greek_names(normalized)


def latex_to_readable_math_text(text: str) -> str:
    cleaned = text.strip()
    cleaned = cleaned.replace("\n", " ")
    cleaned = cleaned.replace(r"\\", " ; ")
    cleaned = cleaned.replace(r"\,", " ")
    cleaned = cleaned.replace(r"\;", " ")
    cleaned = cleaned.replace(r"\!", "")
    cleaned = re.sub(
        r"\\(?:left|right|big|Big|bigg|Bigg|bigl|bigr|Bigl|Bigr|biggl|biggr|Biggl|Biggr)",
        "",
        cleaned,
    )
    cleaned = cleaned.replace(r"\defeq", ":=")
    cleaned = cleaned.replace(r"\eqqcolon", ":=")
    cleaned = cleaned.replace(r"\coloneqq", ":=")

    for _ in range(5):
        before = cleaned
        cleaned = re.sub(
            r"\\frac\{([^{}]+)\}\{([^{}]+)\}",
            lambda match: (
                f"({latex_to_readable_math_text(match.group(1))})/"
                f"({latex_to_readable_math_text(match.group(2))})"
            ),
            cleaned,
        )
        cleaned = re.sub(
            r"\\sqrt\{([^{}]+)\}",
            lambda match: f"√{_root_operand(latex_to_readable_math_text(match.group(1)))}",
            cleaned,
        )
        cleaned = re.sub(
            r"sqrt\(([^()]+)\)",
            lambda match: f"√{_root_operand(latex_to_readable_math_text(match.group(1)))}",
            cleaned,
        )
        cleaned = re.sub(
            r"\\(?:mathrm|mathbf|boldsymbol|mathcal|mathbb|text|operatorname)\{([^{}]+)\}",
            lambda match: latex_to_readable_math_text(match.group(1)),
            cleaned,
        )
        cleaned = re.sub(
            r"\\bar\{([^{}]+)\}",
            lambda match: f"{latex_to_readable_math_text(match.group(1))}\u0304",
            cleaned,
        )
        cleaned = re.sub(
            r"\\bar\s*\\([a-zA-Z]+)",
            lambda match: f"{_replace_named_symbol(match.group(1))}\u0304",
            cleaned,
        )
        cleaned = re.sub(
            r"_\{([^{}]+)\}",
            lambda match: _script_text(match.group(1), subscript=True),
            cleaned,
        )
        cleaned = re.sub(
            r"\^\{([^{}]+)\}",
            lambda match: _script_text(match.group(1), subscript=False),
            cleaned,
        )
        if cleaned == before:
            break

    cleaned = _replace_bare_greek_names(cleaned)

    cleaned = re.sub(
        r"_\\([a-zA-Z]+)",
        lambda match: f"_{_replace_named_symbol(match.group(1))}",
        cleaned,
    )
    cleaned = re.sub(
        r"\^\\([a-zA-Z]+)",
        lambda match: f"^{_replace_named_symbol(match.group(1))}",
        cleaned,
    )
    cleaned = re.sub(
        r"_([A-Za-z0-9+\-=]+)",
        lambda match: _script_text(match.group(1), subscript=True),
        cleaned,
    )
    cleaned = re.sub(
        r"\^\(([A-Za-z0-9+\-=]+)\)",
        lambda match: _script_text(match.group(1), subscript=False),
        cleaned,
    )
    cleaned = re.sub(
        r"\^([A-Za-z0-9+\-=]+)",
        lambda match: _script_text(match.group(1), subscript=False),
        cleaned,
    )

    for source, target in {**_GREEK_REPLACEMENTS, **_SYMBOL_REPLACEMENTS}.items():
        cleaned = re.sub(rf"\\{source}(?![A-Za-z])", target, cleaned)
    cleaned = cleaned.replace("*", "×")
    cleaned = re.sub(r"\\b([A-Za-z])(?![A-Za-z])", r"\1", cleaned)
    cleaned = re.sub(r"\\([A-Za-z]+)\*?", lambda match: match.group(1), cleaned)
    cleaned = cleaned.replace(r"\{", "{").replace(r"\}", "}")
    cleaned = cleaned.replace("{", "").replace("}", "")
    cleaned = re.sub(r"\s+", " ", cleaned).strip()
    cleaned = re.sub(r"\s*([_=+\-/:<>|])\s*", r"\1", cleaned)
    cleaned = re.sub(r"\s*([(),;])\s*", r"\1", cleaned)
    return cleaned


def _root_operand(value: str) -> str:
    if re.fullmatch(r"[\w\u0370-\u03ff\u1d62-\u1d6a\u2080-\u209c]+", value):
        return value
    return f"({value})"


def _script_text(text: str, *, subscript: bool) -> str:
    readable = latex_to_readable_math_text(text)
    table = _SUBSCRIPT_MAP if subscript else _SUPERSCRIPT_MAP
    converted = readable.translate(table)
    if converted != readable and all(
        char in table.values() or char in {"₍", "₎", "⁽", "⁾", ","}
        for char in converted
    ):
        return converted
    if subscript:
        return f"_{readable}"
    return f"^({readable})" if len(readable) > 1 else f"^{readable}"


def _replace_named_symbol(name: str) -> str:
    return _GREEK_REPLACEMENTS.get(name, _SYMBOL_REPLACEMENTS.get(name, name))


def _replace_bare_greek_names(text: str) -> str:
    for source, target in sorted(
        _GREEK_REPLACEMENTS.items(),
        key=lambda item: len(item[0]),
        reverse=True,
    ):
        text = re.sub(rf"(?<![A-Za-z0-9\\]){source}(?![A-Za-z0-9])", target, text)

    # PDF extraction often loses the math boundary in prose such as "2pi".
    return re.sub(r"(?<=\d)pi\b", "π", text)
