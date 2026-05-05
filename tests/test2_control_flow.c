// Test 2: Control flow - if/else and while loop
int main() {
    int x;
    int result;
    int i;
    int sum;

    x = 7;
    result = 0;

    if (x > 5) {
        result = 1;
    } else {
        result = 0;
    }

    if (x >= 10) {
        result = 100;
    } else {
        if (x >= 5) {
            result = 50;
        } else {
            result = 0;
        }
    }

    i = 0;
    sum = 0;
    while (i < 5) {
        sum = sum + i;
        i = i + 1;
    }

    int flag;
    flag = 1;
    if (flag && x > 0) {
        result = result + 1;
    }

    return 0;
}
