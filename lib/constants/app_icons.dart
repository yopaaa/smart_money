import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

class AppIcons {
  static IconData getIcon(String? name) {
    if (name == null || name.isEmpty) return Ionicons.shapes;

    switch (name.toLowerCase()) {
      // Account types
      case 'cash':
      case 'cash-plus':
        return Ionicons.cash;
      case 'account-cash':
        return Ionicons.wallet;
      case 'card':
      case 'credit-card':
      case 'credit-card-outline':
      case 'debit':
        return Ionicons.card;
      case 'saving':
      case 'bank':
        return Ionicons.business;
      case 'invest':
      case 'chart-line':
        return Ionicons.trendingUp;
      case 'liability':
      case 'file-document':
        return Ionicons.documentText;
      case 'debt':
        return Ionicons.people;
      case 'receivable':
      case 'account-arrow-left':
        return Ionicons.personAdd;
      case 'expense-buffer':
      case 'umbrella':
        return Ionicons.umbrella;
      case 'wallet':
      case 'wallet-giftcard':
        return Ionicons.wallet;

      // Expenses categories
      case 'silverware-fork-knife':
      case 'food':
        return Ionicons.restaurant;
      case 'cup-water':
      case 'drink':
        return Ionicons.cafe;
      case 'bus':
      case 'transport':
      case 'car':
        return Ionicons.car;
      case 'shopping':
      case 'cart':
        return Ionicons.cart;
      case 'movie':
      case 'film':
        return Ionicons.film;
      case 'heart-pulse':
      case 'health':
        return Ionicons.heart;
      case 'school':
      case 'education':
        return Ionicons.school;
      case 'hand-heart':
      case 'donate':
        return Ionicons.heartCircle;
      case 'bank-transfer-out':
        return Ionicons.arrowUpCircle;
      case 'bank-transfer-in':
        return Ionicons.arrowDownCircle;
      case 'bank-transfer':
      case 'transfer':
        return Ionicons.swapHorizontal;
      case 'file-cog':
      case 'admin':
        return Ionicons.construct;
      case 'gift':
      case 'party-popper':
        return Ionicons.gift;
      case 'cellphone':
      case 'phone':
        return Ionicons.phonePortrait;
      case 'home':
        return Ionicons.home;
      case 'face-woman':
      case 'skincare':
        return Ionicons.sparkles;
      case 'piggy-bank':
      case 'savings':
        return Ionicons.wallet;
      case 'briefcase':
      case 'work':
        return Ionicons.briefcase;
      case 'safe':
      case 'vault':
        return Ionicons.lockClosed;
      case 'hand-coin':
      case 'currency-usd':
        return Ionicons.cash;
      case 'store':
        return Ionicons.storefront;
      case 'calendar-month':
        return Ionicons.calendar;
      case 'account-circle':
        return Ionicons.personCircle;
      case 'dots-horizontal':
      case 'other':
      default:
        return Ionicons.ellipsisHorizontal;
    }
  }
}
