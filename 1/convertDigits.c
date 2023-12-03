// all digits in strings
// 1st byte indicates digit string length
const static char * const digits[9] = {
    "\003one",
    "\003two",
    "\005three",
    "\004four",
    "\004five",
    "\003six",
    "\005seven",
    "\005eight",
    "\004nine",
};

/*
 * if there's a digit spelled out at the beginning of `candidate`, change it to
 * its digit character. Leave other characters of the string there
 * ex: "one two three mammamia"
 * ->  "1ne two three mammamia"
 * ex: "eighthree"
 * ->  "8igh3hree"
 */
static void convertDigit(char *candidate, int remaining)
{
    int i, j;
    for (i = 0; i < 9; i++) {
        const int digitLen = digits[i][0];
        if (digitLen > remaining)
            continue;    // current digit wouldn't fit, analyze next
        // check if digit string matches
        for (j = 0; j < digitLen; j++) {
            if (candidate[j] != digits[i][j + 1])
                break;
        }
        if (j == digitLen) {
            candidate[0] = '1' + i;
            return;
        }
    }
}

/*
 * convert spelled out digits to their digit characters
 * ex: "one two three mammamia"
 * ->  "1   2   3     mammamia"
 */
void convertDigits(char *line, int len)
{
    int i;
    for (i = 0; i < len; i++) {
        convertDigit(line + i, len - i);
    }
    i = 0;
}
