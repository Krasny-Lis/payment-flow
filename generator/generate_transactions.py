import argparse
import csv
import random
import uuid
from datetime import date, datetime, time, timedelta, timezone
from pathlib import Path


CSV_COLUMNS = [
    "external_transaction_id",
    "terminal_code",
    "transaction_type_code",
    "status_code",
    "payment_method_code",
    "currency_code",
    "amount",
    "occurred_at_utc",
    "authorization_code",
    "card_network",
    "masked_pan",
]


def parse_arguments():
    parser = argparse.ArgumentParser(
        description="Generate test payment transactions."
    )

    parser.add_argument("--rows", type=int, default=1000)
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("data/input/sample_transactions.csv"),
    )
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--start-date", default="2025-01-01")
    parser.add_argument("--end-date", default="2025-12-31")

    return parser.parse_args()


def choose_terminal(randomizer):
    merchant_number = randomizer.randint(1, 50)
    suffix = randomizer.choice(("POS", "MOB", "ECO"))

    terminal_code = f"T{merchant_number:04d}-{suffix}"

    return terminal_code, merchant_number, suffix


def choose_payment_method(randomizer, terminal_suffix):
    if terminal_suffix == "POS":
        methods = ("CARD", "BLIK", "DIGITAL_WALLET")
        weights = (70, 20, 10)
    elif terminal_suffix == "MOB":
        methods = ("CARD", "BLIK", "DIGITAL_WALLET")
        weights = (45, 35, 20)
    else:
        methods = (
            "CARD",
            "BLIK",
            "DIGITAL_WALLET",
            "BANK_TRANSFER",
        )
        weights = (50, 25, 15, 10)

    return randomizer.choices(methods, weights=weights, k=1)[0]


def choose_transaction_type_and_status(randomizer):
    transaction_type = randomizer.choices(
        ("PURCHASE", "REFUND", "REVERSAL"),
        weights=(94, 4, 2),
        k=1,
    )[0]

    if transaction_type == "REFUND":
        return transaction_type, "REFUNDED"

    if transaction_type == "REVERSAL":
        return transaction_type, "REVERSED"

    status = randomizer.choices(
        ("SETTLED", "DECLINED", "AUTHORIZED", "PENDING"),
        weights=(80, 12, 5, 3),
        k=1,
    )[0]

    return transaction_type, status


def choose_currency(merchant_number):
    remainder = merchant_number % 10

    if remainder == 0:
        return "CZK"

    if remainder in (1, 2):
        return "EUR"

    return "PLN"


def generate_amount(randomizer, currency_code):
    amount = randomizer.lognormvariate(3.8, 1.0)
    amount = max(1.0, min(amount, 5000.0))

    if currency_code == "CZK":
        amount *= 5

    return f"{amount:.2f}"


def generate_timestamp(randomizer, start, end):
    total_seconds = int((end - start).total_seconds())
    random_seconds = randomizer.randint(0, total_seconds)
    random_milliseconds = randomizer.randint(0, 999)

    timestamp = (
        start
        + timedelta(seconds=random_seconds)
        + timedelta(milliseconds=random_milliseconds)
    )

    return timestamp.strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"


def generate_card_data(randomizer, payment_method):
    if payment_method not in ("CARD", "DIGITAL_WALLET"):
        return "", ""

    network, prefix = randomizer.choice(
        (
            ("VISA", "411111"),
            ("MASTERCARD", "545454"),
        )
    )

    last_four = f"{randomizer.randint(0, 9999):04d}"
    masked_pan = f"{prefix}******{last_four}"

    return network, masked_pan


def generate_transaction_id(randomizer):
    return str(
        uuid.UUID(
            int=randomizer.getrandbits(128),
            version=4,
        )
    )


def main():
    arguments = parse_arguments()

    if arguments.rows <= 0:
        raise ValueError("--rows must be greater than zero")

    start = datetime.combine(
        date.fromisoformat(arguments.start_date),
        time.min,
        tzinfo=timezone.utc,
    )

    end = datetime.combine(
        date.fromisoformat(arguments.end_date),
        time.max,
        tzinfo=timezone.utc,
    )

    if end < start:
        raise ValueError("--end-date cannot be earlier than --start-date")

    randomizer = random.Random(arguments.seed)

    arguments.output.parent.mkdir(parents=True, exist_ok=True)

    with arguments.output.open(
        "w",
        newline="",
        encoding="utf-8",
    ) as output_file:
        writer = csv.DictWriter(
            output_file,
            fieldnames=CSV_COLUMNS,
            lineterminator="\n",
        )

        writer.writeheader()

        for row_number in range(1, arguments.rows + 1):
            terminal_code, merchant_number, terminal_suffix = (
                choose_terminal(randomizer)
            )

            payment_method = choose_payment_method(
                randomizer,
                terminal_suffix,
            )

            transaction_type, status = (
                choose_transaction_type_and_status(randomizer)
            )

            currency_code = choose_currency(merchant_number)
            card_network, masked_pan = generate_card_data(
                randomizer,
                payment_method,
            )

            authorization_code = ""

            if status in ("AUTHORIZED", "SETTLED"):
                authorization_code = (
                    f"{randomizer.randint(0, 999999):06d}"
                )

            writer.writerow(
                {
                    "external_transaction_id":
                        generate_transaction_id(randomizer),
                    "terminal_code": terminal_code,
                    "transaction_type_code": transaction_type,
                    "status_code": status,
                    "payment_method_code": payment_method,
                    "currency_code": currency_code,
                    "amount": generate_amount(
                        randomizer,
                        currency_code,
                    ),
                    "occurred_at_utc": generate_timestamp(
                        randomizer,
                        start,
                        end,
                    ),
                    "authorization_code": authorization_code,
                    "card_network": card_network,
                    "masked_pan": masked_pan,
                }
            )

            if row_number % 100000 == 0:
                print(f"Generated {row_number:,} rows")

    print(
        f"Created {arguments.output} "
        f"with {arguments.rows:,} transactions."
    )


if __name__ == "__main__":
    main()