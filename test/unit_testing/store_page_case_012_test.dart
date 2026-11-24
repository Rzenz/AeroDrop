import 'package:aerodrop/core/models/review_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Test Case ID: CASE-012', () {
    test(
      'Test Case Description: Customer opens the Kape Kanto store page (38 reviews, average 4.7) | '
      "Expected Result: The store rating reads '4.7' with 38 reviews; a store with no reviews reads 'No reviews yet'",
      () {
        const kape = RatingSummaryModel(averageRating: 4.7, reviewCount: 38);
        expect(kape.hasReviews, isTrue);
        expect(kape.displayRating, '4.7');
        expect(kape.totalReviews, 38);

        expect(RatingSummaryModel.empty.hasReviews, isFalse);
        expect(RatingSummaryModel.empty.displayRating, 'No reviews yet');
      },
    );
  });
}
